# terraform-talos-cp-node

Terraform module for deploying individual Talos Kubernetes control plane nodes on AWS.

## Overview

This module creates a single Talos control plane node with:

- EC2 instance with configurable instance type and disk
- Automatic registration with API server load balancer
- Full Talos machine configuration with OIDC integration
- API server configuration for authentication and audit logging
- Optional control plane workload scheduling
- Cloudflare DNS record for node private IP
- Custom sysctls support

## Usage

```hcl
module "control_plane_node" {
  source = "github.com/katn-solutions/terraform-talos-cp-node"

  # Node Identity
  node_name    = "cp-1"
  node_domain  = "cluster.example.com"
  cluster_name = "production"

  # Instance Configuration
  talos_ami_id            = module.talos_cluster.talos_ami_id
  instance_type           = "m5.xlarge"
  subnet_id               = "subnet-abc123"
  node_security_group_ids = [module.talos_cluster.node_security_group_id]
  node_volume_size        = 100
  node_volume_type        = "gp3"

  # Cluster Integration
  apiserver_target_group_arn = module.talos_cluster.apiserver_lb_target_group_arn
  apiserver_url              = module.talos_cluster.apiserver_lb_url

  # OIDC Configuration
  oidc_configuration = {
    bucket                     = module.talos_cluster.oidc_bucket_name
    ca_file                    = "/path/to/ca.crt"
    client_id                  = "kubernetes"
    groups_claim               = "groups"
    issuer                     = module.talos_cluster.oidc_provider_url
    jwks                       = module.talos_cluster.oidc_jwks_url
    service_account_issuer     = module.talos_cluster.oidc_provider_url
    username_claim             = "email"
  }

  # Talos Secrets
  talos_machine_secrets = {
    cluster_id      = "cluster-uuid"
    cluster_secret  = "base64-secret"
    machine_token   = "base64-token"
    # ... additional secrets
  }

  # DNS
  cloudflare_zone_id = "cloudflare-zone-id"

  # Optional: Placement Group
  group_nodes_together = false

  # Optional: Bootstrap first node
  bootstrap = true

  # Optional: Allow workloads on control plane
  allow_scheduling_control_plane = false

  # Optional: Custom sysctls
  sysctls = {
    "net.core.somaxconn"      = "32768"
    "net.ipv4.tcp_max_syn_backlog" = "8192"
  }
}
```

## Testing

This module includes comprehensive testing using Terratest (Go-based unit tests) and Terraform Compliance (BDD-style policy tests).

### Running Tests Locally

```bash
# Install dependencies (one-time setup)
make init

# Run all tests
make all                    # Runs lint + validation + unit tests

# Run specific test types
make lint                   # Format check + tflint
make test                   # Terraform validation only
make test-unit              # Terratest unit tests (no infrastructure created)
make test-compliance        # BDD compliance tests (requires valid plan)
```

### Test Structure

**Terratest (Unit Tests)** - `test/terraform_test.go`
- Validates module configuration for single and HA control plane setups
- Tests various instance types (t3, c5, m5 series)
- Validates bootstrap mode vs joining node configuration
- Runs in parallel for fast feedback
- No AWS credentials required

**Terraform Compliance (Policy Tests)** - `compliance/control-plane.feature`
- Control plane node compliance: Instance sizing, tagging, security groups
- Storage compliance: EBS volume configuration
- Network compliance: Subnet placement, IAM instance profiles

### CI/CD

Tests run automatically in GitHub Actions on every push and pull request:
- Code formatting (terraform fmt)
- Linting (tflint)
- Validation (terraform validate)
- Unit tests (Terratest)

## Requirements

| Name | Version |
|------|---------|
| terraform | >=1.1.7, <2.0.0 |
| aws | >=5.39.0, <6.0.0 |
| cloudflare | 4.8.0 |
| talos | 0.4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| node_name | Name of the control plane node | `string` | n/a | yes |
| node_domain | Domain name for the node (e.g., cluster.example.com) | `string` | n/a | yes |
| cluster_name | Name of the Kubernetes cluster | `string` | n/a | yes |
| talos_ami_id | Talos AMI ID from cluster module | `string` | n/a | yes |
| instance_type | EC2 instance type (e.g., m5.xlarge) | `string` | n/a | yes |
| subnet_id | Subnet ID for node placement | `string` | n/a | yes |
| node_security_group_ids | List of security group IDs for the node | `list(string)` | n/a | yes |
| node_volume_size | Root volume size in GB | `number` | n/a | yes |
| node_volume_type | Root volume type (gp3, gp2, io2, etc.) | `string` | n/a | yes |
| apiserver_target_group_arn | Target group ARN for API server from cluster module | `string` | n/a | yes |
| apiserver_url | API server URL from cluster module | `string` | n/a | yes |
| oidc_configuration | OIDC configuration object for API server | `object({...})` | n/a | yes |
| talos_machine_secrets | Talos machine secrets for cluster join | `object({...})` | n/a | yes |
| cloudflare_zone_id | Cloudflare Zone ID for DNS record | `string` | n/a | yes |
| group_nodes_together | Use placement group (must match cluster setting) | `bool` | n/a | yes |
| bootstrap | Bootstrap the cluster on this node | `bool` | `false` | no |
| allow_scheduling_control_plane | Allow workload pods on control plane | `bool` | `false` | no |
| root_disk_mount | Root disk device path | `string` | `"/dev/xvda"` | no |
| sysctls | Custom sysctl settings | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| control_plane_config | Talos machine configuration (sensitive) |
| instance_private_ip | Private IP address of the control plane node |

## Talos Machine Configuration

The module generates a complete Talos machine configuration with the following patches applied:

### Base Configuration
- **Install disk**: Configurable via `root_disk_mount` (default: `/dev/xvda`)
- **Hostname**: `${node_name}.${node_domain}`
- **Cluster join**: Uses `apiserver_url` for control plane discovery

### Kubelet Configuration
- **Certificate rotation**: Server certificate rotation enabled
- **Authentication**: Anonymous authentication disabled

### API Server Configuration

#### OIDC Integration
```yaml
oidc-issuer-url: <issuer>
oidc-client-id: <client_id>
oidc-ca-file: <ca_file>
oidc-username-claim: <username_claim>
oidc-groups-claim: <groups_claim>
```

#### Service Account Configuration
```yaml
service-account-issuer: <service_account_issuer>
service-account-jwks-uri: <jwks>
```

#### Audit Policy
- **Audit level**: Metadata
- **Omit stages**: RequestReceived
- **Log backend**: File-based audit logging

### Control Plane Scheduling
When `allow_scheduling_control_plane = false` (default):
- Control plane nodes are tainted to prevent workload scheduling
- Only system pods and daemonsets run on control plane

When `allow_scheduling_control_plane = true`:
- Control plane nodes can run user workloads
- Useful for small clusters or development environments

### Custom Sysctls
Additional kernel parameters can be set via the `sysctls` variable. Common use cases:
- Network buffer tuning
- Connection tracking limits
- File descriptor limits

## Bootstrap Process

The first control plane node must be bootstrapped to initialize the cluster. Set `bootstrap = true` on exactly one control plane node.

**Bootstrapping workflow:**
1. Deploy cluster infrastructure (terraform-talos-cluster)
2. Deploy first control plane node with `bootstrap = true`
3. Wait for node to initialize
4. Deploy additional control plane nodes with `bootstrap = false`
5. Deploy worker nodes

## DNS Records

The module creates an A record in Cloudflare:
- **Name**: `${node_name}.${node_domain}`
- **Value**: Node private IP address
- **TTL**: 1 (automatic)
- **Proxied**: false

This allows internal service discovery and node identification.

## High Availability

For production clusters, deploy multiple control plane nodes (typically 3 or 5):

```hcl
module "cp_node_1" {
  source = "github.com/katn-solutions/terraform-talos-cp-node"
  node_name = "cp-1"
  bootstrap = true  # Only first node
  # ... other configuration
}

module "cp_node_2" {
  source = "github.com/katn-solutions/terraform-talos-cp-node"
  node_name = "cp-2"
  bootstrap = false
  # ... other configuration
}

module "cp_node_3" {
  source = "github.com/katn-solutions/terraform-talos-cp-node"
  node_name = "cp-3"
  bootstrap = false
  # ... other configuration
}
```

## Dependencies

### Required Modules
This module requires outputs from:
- **terraform-talos-cluster**: Provides AMI, target groups, security groups, OIDC configuration

### Deployment Order
1. Deploy `terraform-talos-cluster` (foundation)
2. Deploy `terraform-talos-cp-node` (control plane nodes)
3. Deploy `terraform-talos-worker-node` (worker nodes)

## Security

### API Server Authentication
The API server is configured with OIDC authentication, allowing integration with external identity providers.

### Audit Logging
All API server requests are logged at the metadata level, capturing:
- Request metadata (user, verb, resource)
- Response status
- Timing information

Audit logs are written to the node's filesystem and can be forwarded to centralized logging.

### Certificate Rotation
Kubelet server certificates automatically rotate before expiration, ensuring uninterrupted operation.

## Notes

- Only one node should have `bootstrap = true`
- Control plane nodes register with the API server load balancer on port 6443
- The Talos machine configuration is sensitive and stored in Terraform state
- Placement group must match the cluster configuration
- Root disk must have sufficient space for etcd, containerd images, and logs (minimum 50GB, recommended 100GB)

## License

Proprietary
