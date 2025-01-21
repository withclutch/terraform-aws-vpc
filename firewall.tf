locals {
  aws_region                   = "us-east-2"
  aws_managed_rules_prefix_arn = "arn:aws:network-firewall:${local.aws_region}:aws-managed:stateful-rulegroup"

  // TODO to be reviewed
  aws_managed_rules = [
    #"AbusedLegitMalwareDomainsStrictOrder",
    # "BotNetCommandAndControlDomainsStrictOrder",
    # "AbusedLegitBotNetCommandAndControlDomainsStrictOrder",
    # "MalwareDomainsStrictOrder",
    # "ThreatSignaturesIOCStrictOrder",
    # "ThreatSignaturesPhishingStrictOrder",
    # "ThreatSignaturesBotnetWebStrictOrder",
    # "ThreatSignaturesEmergingEventsStrictOrder",
    # "ThreatSignaturesDoSStrictOrder",
    # "ThreatSignaturesMalwareWebStrictOrder",
    # "ThreatSignaturesExploitsStrictOrder",
    # "ThreatSignaturesWebAttacksStrictOrder",
    # "ThreatSignaturesScannersStrictOrder",
    # "ThreatSignaturesBotnetStrictOrder",
    # "ThreatSignaturesMalwareStrictOrder",
    # "ThreatSignaturesMalwareCoinminingStrictOrder",
    # "ThreatSignaturesFUPStrictOrder",
    # "ThreatSignaturesSuspectStrictOrder",
    # "ThreatSignaturesBotnetWindowsStrictOrder",
  ]

  sync_states = try(module.firewall.status[0].sync_states, {})
  firewall_vpce = {
    for state in local.sync_states : state.availability_zone => {
      cidr_block  = one([for subnet in aws_subnet.firewall : subnet.cidr_block if subnet.id == state.attachment[0].subnet_id])
      endpoint_id = state.attachment[0].endpoint_id
    }
  }
}

module "firewall" {

  # TODO: only create if `create_network_firewall` is true

  source = "terraform-aws-modules/network-firewall/aws"

  # Firewall
  name        = "${var.name}-fw"
  description = var.description

  # Only for example
  delete_protection                 = var.delete_protection
  firewall_policy_change_protection = var.firewall_policy_change_protection
  subnet_change_protection          = var.subnet_change_protection

  # TODO: add validation to require firewall subnets to be defined if `create_network_firewall` is true

  vpc_id = local.vpc_id
  subnet_mapping = { for subnet in aws_subnet.firewall : "subnet-${subnet.id}" => {
    subnet_id       = subnet.id
    ip_address_type = "IPV4"
    }
  }

  # Logging configuration
  create_logging_configuration = false
  // TODO to be reviewed
  # logging_configuration_destination_config = [
  #   {
  #     log_destination = {
  #       logGroup = module.logs_alerts.cloudwatch_log_group_name
  #     }
  #     log_destination_type = "CloudWatchLogs"
  #     log_type             = "ALERT"
  #   },
  #   {
  #     log_destination = {
  #       logGroup = module.logs_flow.cloudwatch_log_group_name
  #     }
  #     log_destination_type = "CloudWatchLogs"
  #     log_type             = "FLOW"
  #   },
  # ]

  # encryption_configuration = {
  #   key_id = module.kms.key_arn
  #   type   = "CUSTOMER_KMS"
  # }

  # Policy
  policy_name        = "${var.name}-fw-policy"
  policy_description = "Default network firewall policy for ${var.name}"

  policy_stateful_rule_group_reference = {
    for i, rule_group in local.aws_managed_rules : rule_group => {
      resource_arn = "${local.aws_managed_rules_prefix_arn}/${rule_group}",
      priority     = i + 1,
    }
  }

  policy_stateful_engine_options = {
    rule_order = "STRICT_ORDER"
  }
  policy_stateless_default_actions          = ["aws:forward_to_sfe"]
  policy_stateless_fragment_default_actions = ["aws:forward_to_sfe"]

  #tags = local.all_input_tags
}
