provider "aws" {
  region = local.region
}

locals {
  region      = "us-east-2"
  name_prefix = random_pet.this.id
}

resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

################################################################################
# KMS
################################################################################

resource "aws_kms_key" "firewall_kms" {
  description             = "KMS key for Network Firewall logs"
  deletion_window_in_days = 10

  tags = {
    Name = "${local.name_prefix}-kms"
  }
}

################################################################################
# Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "firewall_log_flow" {
  name              = "${local.name_prefix}-log-flow"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "firewall_log_alert" {
  name              = "${local.name_prefix}-log-alert"
  retention_in_days = 1
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../"

  name        = "fw-example"

  ######### VPC ##########
  cidr = "10.0.0.0/16"
  azs  = ["${local.region}a", "${local.region}b", "${local.region}c"]

  ######### Subnets ##########
  private_subnets  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  firewall_subnets = ["10.0.3.0/28", "10.0.3.16/28", "10.0.3.32/28"]

  create_multiple_public_route_tables = true

  ######### NAT Gateway ##########
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  ########## Firewall ##########
  create_network_firewall    = true
  enable_network_firewall    = true
  firewall_kms_key_arn       = aws_kms_key.firewall_kms.arn
  firewall_delete_protection = false

  create_network_firewall_logging_configuration = true
  logging_configuration_destination_config      = [for log in
    [
      {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.firewall_log_alert.name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "ALERT"
      },
      {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.firewall_log_flow.name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "FLOW"
      }
    ] : log if contains(["ALERT", "FLOW"], log.log_type)
  ]

  ######### Firewall Rules and Filter ##########
  firewall_managed_rules = [
    "AbusedLegitMalwareDomainsStrictOrder",
    "BotNetCommandAndControlDomainsStrictOrder",
    "AbusedLegitBotNetCommandAndControlDomainsStrictOrder",
    "MalwareDomainsStrictOrder",
    "ThreatSignaturesIOCStrictOrder",
    "ThreatSignaturesPhishingStrictOrder",
    "ThreatSignaturesBotnetWebStrictOrder",
    "ThreatSignaturesEmergingEventsStrictOrder",
    "ThreatSignaturesDoSStrictOrder",
    "ThreatSignaturesMalwareWebStrictOrder",
    "ThreatSignaturesExploitsStrictOrder",
    "ThreatSignaturesWebAttacksStrictOrder",
    "ThreatSignaturesScannersStrictOrder",
    "ThreatSignaturesBotnetStrictOrder",
    "ThreatSignaturesMalwareStrictOrder",
    "ThreatSignaturesMalwareCoinminingStrictOrder",
    "ThreatSignaturesFUPStrictOrder",
    "ThreatSignaturesSuspectStrictOrder",
    "ThreatSignaturesBotnetWindowsStrictOrder",
  ]
}
