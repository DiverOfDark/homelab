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