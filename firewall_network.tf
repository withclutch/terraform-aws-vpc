################################################################################
# Firewall subnets
################################################################################
locals {
  firewall_subnets_map = {
    for i, value in var.firewall_subnets : value => {
      index      = i
      cidr_block = value
    }
  }

  az_to_public_subnet = {
    for public_subnet in aws_subnet.public : public_subnet.availability_zone => {
      id         = public_subnet.id
      cidr_block = public_subnet.cidr_block
    }
  }
}

resource "aws_subnet" "firewall" {
  for_each = var.create_network_firewall == true ? local.firewall_subnets_map : {}

  vpc_id               = local.vpc_id
  cidr_block           = each.value.cidr_block
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, each.value.index))) > 0 ? element(var.azs, each.value.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, each.value.index))) == 0 ? element(var.azs, each.value.index) : null

  tags = merge(
    {
      Name = try(
        var.firewall_subnet_names[each.value.index],
        format("${var.name}-${var.firewall_subnet_suffix}-%s", element(var.azs, each.value.index))
      )
    },
    var.tags,
    var.firewall_subnet_tags,
  )

  depends_on = [
    aws_vpc.this
  ]
}

################################################################################
# Firewall routes
################################################################################
resource "aws_route_table" "firewall" {
  count = length(var.firewall_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.create_multiple_firewall_route_tables ? format(
        "${var.name}-${var.firewall_subnet_suffix}-%s",
        element(var.azs, count.index),
      ) : "${var.name}-${var.firewall_subnet_suffix}"
    },
    var.tags,
    var.firewall_route_table_tags,
  )

  depends_on = [
    aws_vpc.this
  ]
}

resource "aws_route_table_association" "firewall" {
  for_each = aws_subnet.firewall

  subnet_id      = each.value.id
  route_table_id = element(aws_route_table.firewall[*].id, 0)
}

resource "aws_route" "from_firewall_subnet_to_igw" {
  for_each = var.create_network_firewall == true && var.enable_network_firewall == true ? aws_subnet.firewall : {}

  route_table_id         = element(aws_route_table.firewall[*].id, 0)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  depends_on = [
    aws_vpc.this,
    aws_route_table.firewall
  ]
}

resource "aws_route_table" "igw" {
  count = var.create_network_firewall == true ? 1 : 0

  vpc_id = local.vpc_id
  tags = merge(
    {
      "Name" = "${var.name}-${var.igw_subnet_suffix}"
    },
    var.tags
  )
}

resource "aws_route" "from_igw_to_firewall" {
  for_each = var.create_network_firewall == true && var.enable_network_firewall == true ? local.az_to_public_subnet : {} // TODO re-add check by validating it.

  route_table_id         = element(aws_route_table.igw[*].id, 0)
  destination_cidr_block = each.value.cidr_block
  vpc_endpoint_id        = local.firewall_vpce[each.key].endpoint_id

  depends_on = [
    aws_vpc.this,
    aws_route_table.igw
  ]
}
