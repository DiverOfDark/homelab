# Kubernetes Auth Configuration for OpenBao + External Secrets Operator

## Overview
This configuration sets up proper Kubernetes authentication for External Secrets Operator (ESO) to access OpenBao.

## Files

### 1. eso-openbao-auth.yaml
Kubernetes RBAC configuration for ESO to access OpenBao.

```yaml
# eso-openbao-auth.yaml - Apply this after OpenBao is unsealed
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-external-secrets
  namespace: eso
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: eso-role
  namespace: eso
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: eso-role-binding
  namespace: eso
subjects:
- kind: ServiceAccount
  name: eso-external-secrets
  namespace: eso
roleRef:
  kind: Role
  name: eso-role
  apiGroup: rbac.authorization.k8s.io
```

### 2. openbao-k8s-auth-setup.sh
Script to configure Kubernetes auth method inside OpenBao.

```bash
#!/bin/bash
# openbao-k8s-auth-setup.sh - Run this inside OpenBao pod after unsealing

set -e

echo "🔐 Setting up Kubernetes auth method in OpenBao..."

# Enable Kubernetes auth method
bao auth enable kubernetes

# Configure Kubernetes auth method
bao write auth/kubernetes/config \
  kubernetes_host=https://kubernetes.default.svc.cluster.local \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create policy for ESO
echo "📋 Creating ESO policy..."
bao write sys/policies/eso-policy \
  name=eso-policy \
  rules=-<<EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete"]
}
EOF

# Create role for ESO service account
echo "🔑 Creating ESO role..."
bao write auth/kubernetes/role/eso-role \
  bound_service_account_names=eso-external-secrets \
  bound_service_account_namespaces=eso \
  policies=eso-policy \
  ttl=1h

echo "✅ Kubernetes auth setup completed!"
echo ""
echo "📝 Next steps:"
echo "1. Apply the eso-openbao-auth.yaml file: kubectl apply -f eso-openbao-auth.yaml"
echo "2. Test the setup by creating a secret in OpenBao and accessing it via ESO"
```

## Usage

### 1. Apply Kubernetes RBAC
```bash
kubectl apply -f eso-openbao-auth.yaml
```

### 2. Configure OpenBao
Execute the setup script inside the OpenBao pod:
```bash
kubectl exec -it -n openbao openbao-0 -- /bin/sh
/openbao-k8s-auth-setup.sh
```

### 3. Verify Setup
Check that the auth method is enabled:
```bash
bao auth list | grep kubernetes
```

## Troubleshooting

### Common Issues
- **Permission denied**: Ensure the ServiceAccount has correct RBAC bindings
- **Connection refused**: Verify Kubernetes API endpoint is accessible from OpenBao pod
- **TLS errors**: Check if the CA certificate is properly mounted in the OpenBao pod

### Debug Commands
```bash
# Check auth method status
bao auth list

# Check policy
bao read sys/policies/eso-policy

# Test auth method
bao write auth/kubernetes/role/eso-role/config bound_service_account_names=eso-external-secrets
```