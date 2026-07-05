# Ansible — bifrost & tailnet members

Manages the non-Kubernetes machines: **bifrost** (Hetzner VM running headscale,
the tailnet coordination server) and **yggdrasil** (offsite backup mini-PC).
Servers are provisioned by `terraform/hetzner.tf`; ansible does OS config only.

## Running

From the nix dev shell (needs `bao` for the OIDC secret fetch):

```sh
task ansible:plan          # dry run (--check --diff), like tofu plan
task ansible:deploy        # full playbook (fetches OIDC creds from OpenBao itself)
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

## Headscale day-2 commands (on bifrost)

```sh
headscale users create infra                 # one user owning all infrastructure nodes
headscale preauthkeys create --user infra --reusable --expiration 24h
headscale nodes list
headscale nodes approve-routes --identifier <id> --routes <routes>   # approve advertised subnet routes
```

Humans log in via Zitadel OIDC (no preauth keys); infrastructure registers with
preauth keys under the `infra` user.

## Runbook: joining yggdrasil to the tailnet (one-time, manual)

yggdrasil is a mini-PC at a friend's home behind their Fritz!Box. Until it's on
the tailnet, ansible cannot reach it — the only path is the existing Cloudflare
WARP / cloudflared SSH. Bootstrap it by hand:

1. Generate a preauth key on bifrost:

   ```sh
   ssh -p 22320 root@headscale.kirillorlov.pro headscale preauthkeys create --user infra --reusable=false --expiration 1h
   ```

2. SSH to yggdrasil over the current WARP path and run:

   ```sh
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up --login-server=https://headscale.kirillorlov.pro --authkey=<key-from-step-1>
   tailscale status   # note the 100.64.x.x address
   ```

3. Back here: add yggdrasil to `inventory/hosts.yaml` under `tailnet_members`
   with `ansible_host: <its 100.64.x.x IP>`, then run the playbook — from now
   on it's managed over the tailnet.

4. The tailnet IP from step 2 is also what the in-cluster backup consumers
   (velero, CNPG, harbor) get repointed to in Phase 3 — cloudflared on
   yggdrasil stays up until Phase 7.
