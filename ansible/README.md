# Ansible — bifrost & tailnet members

Manages the non-Kubernetes machines: **bifrost** (Hetzner VM running headscale,
the tailnet coordination server) and **yggdrasil** (offsite backup mini-PC).
Servers are provisioned by `terraform/hetzner.tf`; ansible does OS config only.

## Running

From the nix dev shell (needs `bao` for the OIDC secret fetch):

```sh
task ansible:plan          # dry run (--check --diff), like tofu plan
task ansible:deploy        # full playbook (fetches OIDC creds from OpenBao itself)
task ansible:upgrade       # full apt upgrade + autoremove (manual reboot may be needed)
task ansible:ping          # connectivity check
task ansible:preauth-key   # mint a headscale preauth key on bifrost
```

Or manually:

```sh
cd ansible
export HEADSCALE_OIDC_CLIENT_ID=$(bao kv get -field=client_id secret/zitadel/headscale-credentials)
export HEADSCALE_OIDC_CLIENT_SECRET=$(bao kv get -field=client_secret secret/zitadel/headscale-credentials)
ansible-playbook playbooks/site.yaml
```

bifrost is addressed as `headscale.kirillorlov.pro` (resolves to its pinned
hcloud primary IP; fall back to `tofu output bifrost_ipv4` if DNS is broken).
SSH runs on port **22320** (set by cloud-init before first boot; must match
`local.bifrost_ssh_port` in terraform).

## Tailnet preauth key (one-time setup)

All infrastructure joins with a single long-lived reusable preauth key stored
in OpenBao — ansible (Taskfile) and manual joins read it from there. Create it
once (after the first `deploy` has created the `infra` user):

```sh
bao kv put secret/headscale authkey=$(ssh -p 22320 root@headscale.kirillorlov.pro \
  headscale preauthkeys create --user infra --reusable --expiration 87600h)
```

The same value goes into `talos/talenv.sops.yaml` as `TAILSCALE_AUTHKEY` for
the Talos nodes. Rotation: mint a new key, `bao kv put` it, update
talenv.sops.yaml — already-registered nodes are unaffected (the key is only
used at first registration).

## Headscale day-2 commands (on bifrost)

```sh
headscale nodes list
headscale nodes approve-routes --identifier <id> --routes <routes>   # approve advertised subnet routes
```

Humans log in via Zitadel OIDC (no preauth keys); infrastructure registers
under the `infra` user (created by the playbook).

## Runbook: joining yggdrasil to the tailnet (one-time, manual)

yggdrasil is a mini-PC at a friend's home behind their Fritz!Box. Until it's on
the tailnet, ansible cannot reach it — the only path is the existing Cloudflare
WARP / cloudflared SSH. Bootstrap it by hand:

1. Grab the shared preauth key: `bao kv get -field=authkey secret/headscale`

2. SSH to yggdrasil over the current WARP path and run:

   ```sh
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up --login-server=https://headscale.kirillorlov.pro --authkey=<key-from-step-1>
   tailscale status   # confirm it registered
   ```

3. Back here: add yggdrasil to `inventory/hosts.yaml` under `tailnet_members`
   with `ansible_host: yggdrasil.ts.kirillorlov.pro` (MagicDNS — your
   workstation is a tailnet member), then run the playbook — from now on it's
   managed over the tailnet.

4. In-cluster backup consumers (velero, CNPG, harbor) get repointed to
   `yggdrasil.ts.kirillorlov.pro` in Phase 3 — cloudflared on yggdrasil stays
   up until Phase 7.

## Hermes (KubeVirt VM)

The "claw" KubeVirt VM (exposed as hermes) runs the hermes voice-assistant agent.
It is a Debian VM inside the cluster. The Tailscale hostname follows the VM name ("claw").

Bootstrap tailscale (one-time):

1. Get preauth key: `bao kv get -field=authkey secret/headscale`

2. Reach the VM for initial bootstrap (if tailscale isn't installed yet):
   - `virtctl console claw -n kubevirt-vms`, or
   - `ssh diverofdark@192.168.179.20` (if your workstation is on the LAN and can reach the MetalLB IP).

3. Inside the VM:
   ```sh
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up --login-server=https://headscale.kirillorlov.pro --authkey=<key>
   tailscale status
   ```

4. Add to `inventory/hosts.yaml` under `tailnet_members`:
   ```yaml
   hermes:
     ansible_host: claw.ts.kirillorlov.pro
     ansible_user: diverofdark
     ansible_become: true
     nftables_open_tcp_ports: [8642, 9119, 9100]
   ```

   Ports:
   - 8642: Hermes API
   - 9119: Hermes WebUI
   - 9100: node-exporter (for monitoring)

   (Tailscale is used for Ansible reachability now that the VM has joined the tailnet.)

5. Run the playbook. From now on Ansible manages it over the tailnet (base + tailscale).

## Freya (KubeVirt VM — second hermes instance)

`freya` is a second Debian KubeVirt VM (`k3s-userapps/kubevirt-vms/freya-*.yaml`)
running its own hermes-agent, for Kirill's wife. It is a copy of the claw/hermes
VM with two deliberate differences:

- its root DataVolume is **RWX + Block**, and the VM sets
  `evictionStrategy: LiveMigrate`, so it live-migrates instead of being shut
  down when a node drains. (`claw-root` is stuck RWO — accessModes are
  immutable once the PVC is bound, so claw still can't migrate.)
- no `sa-disk` / cluster-admin ServiceAccount — freya only runs hermes.

Endpoints: `freya-api` LoadBalancer on `192.168.179.22`
(:22 → guest :22320, :8642 API, :9119 WebUI), Ingresses `freya.kirillorlov.pro`
(API) and `freya-ui.kirillorlov.pro` (dashboard).

Bootstrap tailscale (one-time):

1. Get preauth key: `bao kv get -field=authkey secret/headscale`

2. `ssh diverofdark@192.168.179.22` from the LAN — works from first boot with
   the cloud-init key. (cloud-init sets no password, so `virtctl console` is a
   dead end; keep sshd on :22 so the Service's :22 -> :22 hop never breaks.)

3. Inside the VM:
   ```sh
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up --login-server=https://headscale.kirillorlov.pro --authkey=<key>
   tailscale status
   ```

4. Install hermes-agent in `~/.hermes` (app-managed, same as on hermes) — do
   this *before* the playbook: the `hermes` role edits `~/.hermes/.env` and
   fails if it doesn't exist yet. Give freya its **own** Telegram bot token /
   API key; sharing hermes's would make both instances poll the same bot.

5. `ansible-playbook playbooks/site.yaml --limit freya` — base hardening +
   tailscale + the `hermes` role (caddy, `hermes-dashboard` user unit). Both
   VMs are covered by the `hermes_vms` group.

Check migratability once it is running:

```sh
kubectl get vmi freya -n kubevirt-vms -o jsonpath='{.status.conditions}' | jq
# LiveMigratable must be True; then:
virtctl migrate freya -n kubevirt-vms
```
