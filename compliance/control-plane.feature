Feature: Control Plane Node compliance
  As a cluster administrator
  I want to ensure control plane nodes are properly configured
  So that the Kubernetes control plane is reliable and secure

  Scenario: Control plane nodes must have proper instance sizing
    Given I have aws_instance defined
    Then it must have instance_type
    And it must have ami

  Scenario: Control plane nodes must be properly tagged
    Given I have aws_instance defined
    Then it must have tags
    And it must have tags.Cluster
    And it must have tags.Role
    And its tags.Role must be control-plane

  Scenario: Control plane nodes must be in a private subnet
    Given I have aws_instance defined
    Then it must have subnet_id

  Scenario: Control plane nodes must have security groups configured
    Given I have aws_instance defined
    Then it must have vpc_security_group_ids

  Scenario: Control plane nodes must use EBS volumes
    Given I have aws_instance defined
    Then it must have root_block_device

  Scenario: Control plane EBS volumes should use gp3 for better performance
    Given I have aws_instance defined
    When it has root_block_device
    Then it must have volume_type

  Scenario: Control plane nodes must have user data for Talos configuration
    Given I have aws_instance defined
    Then it must have user_data
    Or it must have user_data_base64

  Scenario: Launch templates should specify network interfaces
    Given I have aws_launch_template defined
    When it has network_interfaces
    Then it must have network_interfaces.security_groups
    Or it must have network_interfaces.associate_public_ip_address

  Scenario: IAM instance profiles should be configured for AWS integrations
    Given I have aws_instance defined
    Then it must contain iam_instance_profile
    Or it must contain tags
