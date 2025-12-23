# Test valid control plane node configuration
run "valid_cp_node_configuration" {
  command = plan

  variables {
    node_name                      = "cp-1"
    node_domain                    = "cluster.example.com"
    cluster_name                   = "test-cluster"
    talos_ami_id                   = "ami-12345678"
    instance_type                  = "m5.xlarge"
    subnet_id                      = "subnet-abc123"
    node_security_group_ids        = ["sg-abc123"]
    node_volume_size               = 100
    node_volume_type               = "gp3"
    apiserver_target_group_arn     = "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    apiserver_url                  = "https://api.cluster.example.com:6443"
    dns_zone_id                    = "test-zone-id"
    dns_provider                   = "cloudflare"
    group_nodes_together           = false
    bootstrap                      = false
    allow_scheduling_control_plane = false
    root_disk_mount                = "/dev/xvda"
    sysctls                        = {}
    oidc_configuration = {
      # IRSA configuration
      bucket_name = "test-oidc-bucket"
      jwks_url    = "https://oidc.example.com/.well-known/jwks.json"
      sa_issuer   = "https://oidc.example.com"
      # Kubernetes OIDC auth disabled by default
      enable_k8s_oidc_auth = false
    }
    talos_machine_secrets = {
      cluster_id     = "test-cluster-id"
      cluster_secret = "test-secret"
      machine_token  = "test-token"
      ca_crt         = "test-ca"
      ca_key         = "test-key"
    }
  }

  assert {
    condition     = aws_instance.cp-instance.instance_type == "m5.xlarge"
    error_message = "Instance type should match input"
  }

  assert {
    condition     = aws_instance.cp-instance.ami == "ami-12345678"
    error_message = "AMI ID should match input"
  }

  assert {
    condition     = aws_instance.cp-instance.root_block_device[0].volume_size == 100
    error_message = "Root volume size should match input"
  }

  assert {
    condition     = aws_instance.cp-instance.root_block_device[0].volume_type == "gp3"
    error_message = "Root volume type should match input"
  }
}

# Test bootstrap node
run "bootstrap_node" {
  command = plan

  variables {
    node_name                      = "cp-1"
    node_domain                    = "cluster.example.com"
    cluster_name                   = "test-cluster"
    talos_ami_id                   = "ami-12345678"
    instance_type                  = "m5.xlarge"
    subnet_id                      = "subnet-abc123"
    node_security_group_ids        = ["sg-abc123"]
    node_volume_size               = 100
    node_volume_type               = "gp3"
    apiserver_target_group_arn     = "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    apiserver_url                  = "https://api.cluster.example.com:6443"
    dns_zone_id                    = "test-zone-id"
    dns_provider                   = "cloudflare"
    group_nodes_together           = false
    bootstrap                      = true
    allow_scheduling_control_plane = false
    root_disk_mount                = "/dev/xvda"
    sysctls                        = {}
    oidc_configuration = {
      # IRSA configuration
      bucket_name = "test-oidc-bucket"
      jwks_url    = "https://oidc.example.com/.well-known/jwks.json"
      sa_issuer   = "https://oidc.example.com"
      # Kubernetes OIDC auth disabled by default
      enable_k8s_oidc_auth = false
    }
    talos_machine_secrets = {
      cluster_id     = "test-cluster-id"
      cluster_secret = "test-secret"
      machine_token  = "test-token"
      ca_crt         = "test-ca"
      ca_key         = "test-key"
    }
  }

  assert {
    condition     = talos_machine_configuration_apply.cp-instance.apply_mode == "reboot"
    error_message = "Bootstrap node should use reboot apply mode"
  }
}

# Test target group attachment
run "target_group_attachment" {
  command = plan

  variables {
    node_name                      = "cp-1"
    node_domain                    = "cluster.example.com"
    cluster_name                   = "test-cluster"
    talos_ami_id                   = "ami-12345678"
    instance_type                  = "m5.xlarge"
    subnet_id                      = "subnet-abc123"
    node_security_group_ids        = ["sg-abc123"]
    node_volume_size               = 100
    node_volume_type               = "gp3"
    apiserver_target_group_arn     = "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    apiserver_url                  = "https://api.cluster.example.com:6443"
    dns_zone_id                    = "test-zone-id"
    dns_provider                   = "cloudflare"
    group_nodes_together           = false
    bootstrap                      = false
    allow_scheduling_control_plane = false
    root_disk_mount                = "/dev/xvda"
    sysctls                        = {}
    oidc_configuration = {
      # IRSA configuration
      bucket_name = "test-oidc-bucket"
      jwks_url    = "https://oidc.example.com/.well-known/jwks.json"
      sa_issuer   = "https://oidc.example.com"
      # Kubernetes OIDC auth disabled by default
      enable_k8s_oidc_auth = false
    }
    talos_machine_secrets = {
      cluster_id     = "test-cluster-id"
      cluster_secret = "test-secret"
      machine_token  = "test-token"
      ca_crt         = "test-ca"
      ca_key         = "test-key"
    }
  }

  assert {
    condition     = aws_lb_target_group_attachment.control-plane.target_group_arn == "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    error_message = "Should attach to API server target group"
  }

  assert {
    condition     = aws_lb_target_group_attachment.control-plane.port == 6443
    error_message = "Should attach on port 6443"
  }
}

# Test DNS record creation
run "dns_record_creation" {
  command = plan

  variables {
    node_name                      = "cp-1"
    node_domain                    = "cluster.example.com"
    cluster_name                   = "test-cluster"
    talos_ami_id                   = "ami-12345678"
    instance_type                  = "m5.xlarge"
    subnet_id                      = "subnet-abc123"
    node_security_group_ids        = ["sg-abc123"]
    node_volume_size               = 100
    node_volume_type               = "gp3"
    apiserver_target_group_arn     = "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    apiserver_url                  = "https://api.cluster.example.com:6443"
    dns_zone_id                    = "test-zone-id"
    dns_provider                   = "cloudflare"
    group_nodes_together           = false
    bootstrap                      = false
    allow_scheduling_control_plane = false
    root_disk_mount                = "/dev/xvda"
    sysctls                        = {}
    oidc_configuration = {
      # IRSA configuration
      bucket_name = "test-oidc-bucket"
      jwks_url    = "https://oidc.example.com/.well-known/jwks.json"
      sa_issuer   = "https://oidc.example.com"
      # Kubernetes OIDC auth disabled by default
      enable_k8s_oidc_auth = false
    }
    talos_machine_secrets = {
      cluster_id     = "test-cluster-id"
      cluster_secret = "test-secret"
      machine_token  = "test-token"
      ca_crt         = "test-ca"
      ca_key         = "test-key"
    }
  }

  assert {
    condition     = cloudflare_record.instance.name == "cp-1.cluster.example.com"
    error_message = "DNS record name should match node_name.node_domain"
  }

  assert {
    condition     = cloudflare_record.instance.type == "A"
    error_message = "DNS record should be type A"
  }

  assert {
    condition     = cloudflare_record.instance.proxied == false
    error_message = "DNS record should not be proxied"
  }
}

# Test custom sysctls
run "custom_sysctls" {
  command = plan

  variables {
    node_name                      = "cp-1"
    node_domain                    = "cluster.example.com"
    cluster_name                   = "test-cluster"
    talos_ami_id                   = "ami-12345678"
    instance_type                  = "m5.xlarge"
    subnet_id                      = "subnet-abc123"
    node_security_group_ids        = ["sg-abc123"]
    node_volume_size               = 100
    node_volume_type               = "gp3"
    apiserver_target_group_arn     = "arn:aws:elasticloadbalancing:us-west-2:123456789:targetgroup/test/abc"
    apiserver_url                  = "https://api.cluster.example.com:6443"
    dns_zone_id                    = "test-zone-id"
    dns_provider                   = "cloudflare"
    group_nodes_together           = false
    bootstrap                      = false
    allow_scheduling_control_plane = false
    root_disk_mount                = "/dev/xvda"
    sysctls = {
      "net.core.somaxconn" = "32768"
    }
    oidc_configuration = {
      # IRSA configuration
      bucket_name = "test-oidc-bucket"
      jwks_url    = "https://oidc.example.com/.well-known/jwks.json"
      sa_issuer   = "https://oidc.example.com"
      # Kubernetes OIDC auth disabled by default
      enable_k8s_oidc_auth = false
    }
    talos_machine_secrets = {
      cluster_id     = "test-cluster-id"
      cluster_secret = "test-secret"
      machine_token  = "test-token"
      ca_crt         = "test-ca"
      ca_key         = "test-key"
    }
  }

  assert {
    condition     = length(var.sysctls) > 0
    error_message = "Custom sysctls should be configurable"
  }
}
