provider "aws" {
  region = local.region
}

locals {
  region      = "us-east-2"
  name_prefix = random_pet.this.id
  environment = "test"
}

resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

################################################################################
# KMS Module
################################################################################

module "kms" {
  source = "git::https://github.com/withclutch/terraform-modules-registry?ref=aws-kms_v1.204"

  name                              = "${local.name_prefix}-kms"
  environment                       = "test"
  description                       = "KMS key used to test the ${local.name_prefix} AWS Network Firewall"
  allow_usage_in_network_log_groups = true
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../"

  environment = "test"
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
  create_network_firewall = true
  enable_network_firewall = true

  ######### Firewall Logs ##########
  firewall_logs_retention_in_days = 14
  create_logging_configuration    = true

  ######### Firewall Rules and Filter ##########
  firewall_log_types = ["FLOW", "ALERT"]
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

  depends_on = [module.kms]
}
