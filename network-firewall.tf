locals {
  aws_managed_rules_prefix_arn  = "arn:aws:network-firewall:${var.region}:aws-managed:stateful-rulegroup"
  firewall_managed_rules        = distinct(var.firewall_managed_rules)
  name                          = "${var.name}-network-firewall"
}

module "firewall" {
  source  = "terraform-aws-modules/network-firewall/aws"
  version = "~> 1.0"

  count = var.create_network_firewall ? 1 : 0

  name        = local.name
  description = var.firewall_description

  delete_protection                 = var.firewall_delete_protection
  firewall_policy_change_protection = var.firewall_policy_change_protection
  subnet_change_protection          = var.firewall_subnet_change_protection

  vpc_id = aws_vpc.this[0].id
  subnet_mapping = { for subnet_id in aws_subnet.firewall.*.id :
    "subnet-${subnet_id}" => {
      subnet_id       = subnet_id
      ip_address_type = "IPV4"
    }
  }

  ### Logging configuration ###
  create_logging_configuration             = var.create_network_firewall_logging_configuration
  logging_configuration_destination_config = var.logging_configuration_destination_config

  encryption_configuration = {
    key_id = var.firewall_kms_key_arn
    type   = "CUSTOMER_KMS"
  }

  ### Policy composed by custom and managed rules ###
  policy_name        = local.name
  policy_description = "Default network firewall policy for ${local.name}"

  policy_stateful_rule_group_reference = merge(
    {
      for i, rule_group in local.firewall_managed_rules : rule_group => {
        resource_arn = "${local.aws_managed_rules_prefix_arn}/${rule_group}",
        priority     = i + 1,
      }
    },
    {
      for rule_key, rule in module.network_firewall_stateful_rule_groups[0].wrapper :
      rule_key => {
        resource_arn = rule.arn,
        priority     = length(local.firewall_managed_rules) + length(module.network_firewall_stateful_rule_groups[0].wrapper) + 1
      }
  })

  policy_stateful_engine_options = {
    rule_order = "STRICT_ORDER"
  }

  policy_stateless_default_actions          = ["aws:forward_to_sfe"]
  policy_stateless_fragment_default_actions = ["aws:forward_to_sfe"]

  policy_stateless_rule_group_reference = zipmap(keys(module.network_firewall_stateless_rule_groups[0].wrapper),
    [for k, v in module.network_firewall_stateless_rule_groups[0].wrapper : {
      priority     = index(keys(module.network_firewall_stateless_rule_groups[0].wrapper), k) + 1
      resource_arn = v.arn
    }]
  )

  tags = var.tags
}

module "network_firewall_stateless_rule_groups" {
  source  = "terraform-aws-modules/network-firewall/aws//wrappers/rule-group"
  version = "~> 1.0"

  count = var.create_network_firewall ? 1 : 0

  defaults = var.network_firewall_stateless_rule_group_defaults
  items    = var.network_firewall_stateless_rule_group_items
}

module "network_firewall_stateful_rule_groups" {
  source  = "terraform-aws-modules/network-firewall/aws//wrappers/rule-group"
  version = "~> 1.0"

  count = var.create_network_firewall ? 1 : 0

  defaults = var.network_firewall_stateful_rule_group_defaults
  items    = var.network_firewall_stateful_rule_group_items
}

