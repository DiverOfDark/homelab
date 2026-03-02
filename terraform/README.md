# Terraform Infrastructure as Code for Cloudflare Management

This directory contains a modular and well-structured Terraform configuration for managing Cloudflare resources including DNS, tunnels, email routing, and Zero Trust security.

## Structure

```
terraform/
├── main.tf                    # Main configuration file
├── variables.tf               # Input variables with defaults
├── outputs.tf                # Outputs and results
├── versions.tf                # Terraform and provider versions
├── modules/                   # Reusable modules
│   ├── cloudflare-zone/      # Cloudflare account and zone management
│   ├── cloudflare-dns/       # DNS record management
│   ├── cloudflare-tunnel/    # Cloudflare tunnel configuration
│   └── kubernetes-secrets/   # Kubernetes secrets for cloudflared
```

## Features

### 1. Cloudflare Zone Management
- Account creation and management
- Zone configuration
- Account member management

### 2. DNS Management
- DNS record creation and management
- Support for CNAME, A, TXT, and other record types
- Dynamic record creation with loops

### 3. Cloudflare Tunnel
- Secure tunnel creation
- Ingress rule configuration
- Virtual network setup
- Home network routing

### 4. Email Routing
- Email forwarding rules
- Catch-all configuration
- DMARC, SPF, and DKIM records

### 5. Zero Trust Security
- Identity providers (GitHub, One-Time PIN)
- Access policies
- Gateway policies
- DNS location management

### 6. Kubernetes Integration
- Secret management for cloudflared
- Service account creation
- RBAC configuration
- Cert-manager integration

## Usage

### Quick Start
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### With Custom Variables
```bash
terraform apply -var="cloudflare_api_token=your-token"
terraform apply -var="tunnel_secret=your-secret"
```

### Using Different Values
```bash
terraform apply -var="cloudflare_email=different@email.com"
```

## Configuration

### Default Values
All variables have sensible defaults defined in `variables.tf`:
- Cloudflare email: `diverofdark@gmail.com`
- Zone: `kirillorlov.pro`
- Tunnel name: `k8s`
- Kubernetes namespace: `cloudflared`

### Variables Override
You can override any variable by:
1. Command line: `-var="variable_name=value"`
2. Environment variables: `TF_VAR_variable_name=value`
3. `.tfvars` files

## Modules

### cloudflare-zone
- Creates Cloudflare account and zone
- Manages account members
- Outputs account and zone IDs

### cloudflare-dns
- Creates DNS records
- Supports multiple record types
- Outputs created records

### cloudflare-tunnel
- Creates Cloudflare tunnel
- Configures ingress rules
- Sets up virtual networks
- Outputs tunnel details

### kubernetes-secrets
- Creates Kubernetes secrets
- Sets up service accounts
- Configures RBAC
- Integrates with cert-manager

## Security Features

### Zero Trust Access
- GitHub OAuth integration
- One-time PIN authentication
- Email-based access policies

### Email Security
- DMARC records
- SPF records
- DKIM records
- Email routing rules

### Network Security
- Gateway policies
- DNS filtering
- Access controls

## Outputs

The configuration provides comprehensive outputs:
- `zone_id` and `account_id` for reference
- `tunnel_id` and `tunnel_token` for tunnel management
- `dns_records` for DNS management
- `kubernetes_secrets` for Kubernetes integration

## Backend

Uses Kubernetes backend for state management:
- Stores state in Kubernetes secrets
- Namespace: `github-runner`
- Secret suffix: `state`

## Best Practices

1. **Modularity**: Each component is separated into its own module
2. **Reusability**: Modules can be used in other projects
3. **Defaults**: Sensible defaults allow quick start
4. **Security**: Secrets are properly managed
5. **Documentation**: Comprehensive documentation and comments

## Migration

This refactored version replaces the previous monolithic `cloudflare.tf` with:
- Better organization
- Reusable modules
- Clear separation of concerns
- Enhanced maintainability

## Example Usage

```hcl
# Get outputs after apply
terraform output zone_id
terraform output tunnel_id
terraform output cname

# Access Kubernetes secrets
terraform output kubernetes_secrets
```

## Next Steps

1. Replace placeholder values in variables
2. Test with `terraform plan`
3. Apply with `terraform apply`
4. Verify Cloudflare resources are created
5. Configure cloudflared in Kubernetes