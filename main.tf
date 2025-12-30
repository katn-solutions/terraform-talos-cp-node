variable "node_name" {
  type        = string
  description = "Name of the control plane node"
}

variable "group_nodes_together" {
  type        = bool
  description = "Whether to group nodes together"
}

variable "talos_ami_id" {
  type        = string
  description = "AMI ID for Talos Image"
}

variable "instance_type" {
  type        = string
  description = "AWS Instance type"
}

variable "subnet_id" {
  type        = string
  description = "AWS Subnet ID for instance placement"
}

variable "node_security_group_ids" {
  type        = list(string)
  description = "List of security group ID's for application to the node"
}

variable "node_volume_size" {
  type        = number
  description = "Node root volume size in GB"
}

variable "node_volume_type" {
  type        = string
  description = "Node volume type"
}

variable "node_domain" {
  type        = string
  description = "Domain of the node"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}

variable "apiserver_target_group_arn" {
  type        = string
  description = "ARN for the apiserver load balancer"
}

variable "apiserver_url" {
  type        = string
  description = "URL for apiserver load balancer"
}

variable "talos_api_target_group_arn" {
  type        = string
  description = "ARN for the Talos API load balancer target group (optional, empty string to disable)"
  default     = ""
}

variable "dns_provider" {
  description = "DNS provider to use (cloudflare or route53)"
  type        = string
  validation {
    condition     = contains(["cloudflare", "route53"], var.dns_provider)
    error_message = "dns_provider must be either 'cloudflare' or 'route53'"
  }
}

variable "dns_zone_id" {
  type        = string
  description = "DNS Zone ID (Cloudflare Zone ID or Route53 Hosted Zone ID)"
}

variable "oidc_configuration" {
  type = object({
    # IRSA (IAM Roles for Service Accounts) - Required
    bucket_name = string
    jwks_url    = string
    sa_issuer   = string

    # Kubernetes OIDC Authentication - Optional (defaults to disabled)
    enable_k8s_oidc_auth = optional(bool, false)
    ca_file_path         = optional(string, "")
    client_id            = optional(string, "")
    groups_claim         = optional(string, "")
    issuer_url           = optional(string, "")
    username_claim       = optional(string, "")
  })
  description = "OIDC configuration for IRSA and optional Kubernetes OIDC authentication"
}

variable "allow_scheduling_control_plane" {
  type    = bool
  default = false
}

variable "root_disk_mount" {
  type    = string
  default = "/dev/xvda"
}

variable "bootstrap" {
  type    = bool
  default = false
}

variable "sysctls" {
  type        = map(string)
  description = "sysctls to configure"
  default     = null

}

variable "enable_aws_iam_authenticator" {
  type        = bool
  description = "Enable AWS IAM Authenticator webhook authentication"
  default     = false
}

resource "aws_instance" "cp-instance" {
  ami                    = var.talos_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  placement_group        = var.group_nodes_together ? var.cluster_name : null
  vpc_security_group_ids = var.node_security_group_ids

  root_block_device {
    volume_size = var.node_volume_size
    volume_type = var.node_volume_type
  }

  tags = {
    Name    = var.node_name
    Cluster = var.cluster_name
  }
}

resource "aws_lb_target_group_attachment" "control-plane" {
  port             = 6443
  target_group_arn = var.apiserver_target_group_arn
  target_id        = aws_instance.cp-instance.id
}

resource "aws_lb_target_group_attachment" "talos-api" {
  count            = var.talos_api_target_group_arn != "" ? 1 : 0
  port             = 50000
  target_group_arn = var.talos_api_target_group_arn
  target_id        = aws_instance.cp-instance.id
}

# DNS - Cloudflare
resource "cloudflare_record" "instance" {
  count   = var.dns_provider == "cloudflare" ? 1 : 0
  zone_id = var.dns_zone_id
  type    = "A"
  name    = var.node_name
  value   = aws_instance.cp-instance.private_ip
  proxied = false
  ttl     = 60
}

# DNS - Route53
resource "aws_route53_record" "instance" {
  count   = var.dns_provider == "route53" ? 1 : 0
  zone_id = var.dns_zone_id
  name    = var.node_name
  type    = "A"
  ttl     = 60
  records = [aws_instance.cp-instance.private_ip]
}

variable "talos_machine_secrets" {
  description = "talos machine secrets for cluster"
  type = object({
    id            = string
    talos_version = string
    machine_secrets = object({
      certs = object({
        etcd : object({
          cert = string
          key  = string
        })
        k8s = object({
          cert = string
          key  = string
        })
        k8s_aggregator = object({
          cert = string
          key  = string
        })
        k8s_serviceaccount = object({
          key = string
        })
        os = object({
          cert = string
          key  = string
        })
      })
      cluster = object({
        id     = string
        secret = string
      })
      secrets = object({
        bootstrap_token             = string
        secretbox_encryption_secret = string

      })
      trustdinfo = object({
        token = string
      })
    })
    client_configuration = object({
      ca_certificate     = string
      client_certificate = string
      client_key         = string
    })
  })
}

data "talos_machine_configuration" "control_plane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = var.apiserver_url
  machine_secrets  = var.talos_machine_secrets.machine_secrets
}

output "control_plane_config" {
  value     = data.talos_machine_configuration.control_plane
  sensitive = true
}

resource "talos_machine_configuration_apply" "cp-instance" {
  client_configuration        = var.talos_machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = aws_instance.cp-instance.private_ip
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = var.root_disk_mount
        }
        network = {
          hostname : "${var.node_name}.${var.node_domain}"
        }
        kubelet = {
          extraArgs = {
            rotate-server-certificates = true
          }
        }
        sysctls = var.sysctls
      },
      cluster = {
        allowSchedulingOnControlPlanes : var.allow_scheduling_control_plane
        apiServer = merge(
          {
            auditPolicy : {
              apiVersion : "audit.k8s.io/v1"
              kind : "Policy"
              rules : [
                {
                  level : "Metadata"
                }
              ]
            }
            extraArgs = merge(
              {
                # IRSA (Service Account) configuration - always enabled
                service-account-issuer : var.oidc_configuration.sa_issuer
                service-account-jwks-uri : var.oidc_configuration.jwks_url
              },
              # Kubernetes OIDC Authentication - only add if enabled
              var.oidc_configuration.enable_k8s_oidc_auth ? {
                oidc-issuer-url : var.oidc_configuration.issuer_url
                oidc-client-id : var.oidc_configuration.client_id
                oidc-ca-file : var.oidc_configuration.ca_file_path
                oidc-username-claim : var.oidc_configuration.username_claim
                oidc-groups-claim : var.oidc_configuration.groups_claim
              } : {},
              # AWS IAM Authenticator - only add if enabled
              var.enable_aws_iam_authenticator ? {
                authentication-token-webhook-config-file : "/etc/kubernetes/aws-iam-authenticator/kubeconfig.yaml"
              } : {}
            )
          },
          # AWS IAM Authenticator extraVolumes - only add if enabled
          var.enable_aws_iam_authenticator ? {
            extraVolumes : [
              {
                hostPath : "/etc/kubernetes/aws-iam-authenticator/"
                mountPath : "/etc/kubernetes/aws-iam-authenticator/"
                readonly : true
              }
            ]
          } : {}
        )
      }
    })
  ]
}

output "instance_private_ip" {
  value = aws_instance.cp-instance.private_ip
}

resource "talos_machine_bootstrap" "this" {
  count                = var.bootstrap ? 1 : 0
  client_configuration = var.talos_machine_secrets.client_configuration
  node                 = aws_instance.cp-instance.private_ip
  depends_on           = [talos_machine_configuration_apply.cp-instance]
}
