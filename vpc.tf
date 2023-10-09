#VPC only fetch the Availability zones within a region
data "aws_availability_zones" "ecs_az" {
    state = "available"
    filter {
        name = "opt-in-status"
        values = ["opt-in-not-required"]
    }
}

#Create a VPC inside AWS cloud for hosting our services.
resource "aws_vpc" "ecs_vpc" {
    cidr_block              = var.vpc_cidr
    instance_tenancy        = "default"
    enable_dns_hostnames    = true
    enable_dns_support      = true

    tags = {
        Name        = "${var.app_name}-vpc"
        Environment = "${var.app_env}"
    }
}


#Create an internet gateway allowing resources in public subnets to access the outside world.
resource "aws_internet_gateway" "ecs_internet_gw" {
    vpc_id = aws_vpc.ecs_vpc.id

    tags = {
        Name            = "${var.app_name}-internet-gw"
        Environment     = "${var.app_env}"
    }
}

#Create public subnets in different availability zones
resource "aws_subnet" "ecs_public" {
    count                   = var.subnet_count
    vpc_id                  = aws_vpc.ecs_vpc.id
    cidr_block              = cidrsubnet(var.vpc_cidr, 2, count.index)
    availability_zone       = data.aws_availability_zones.ecs_az.names[count.index % var.az_count]
    map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-sn-${count.index}"
    Environment = "${var.app_env}"
  }
}

#Create VPC routing table
resource "aws_route_table" "ecs_rtb_public" {
    vpc_id = aws_vpc.ecs_vpc.id

    tags = {
        Name            = "${var.app_name}-public-rtb"
        Environment     = "${var.app_env}"
    }
}

#Associate route for the public subnet in the VPC route table.
resource "aws_route" "ecs_route_public" {
    route_table_id          = aws_route_table.ecs_rtb_public.id
    destination_cidr_block  = "0.0.0.0/0"
    gateway_id              = aws_internet_gateway.ecs_internet_gw.id
}

#Create a routing table entry in the VPC routing table for all the public subnets.
resource "aws_route_table_association" "ecs_rtba_public" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.ecs_public.*.id, count.index)
  route_table_id = aws_route_table.ecs_rtb_public.id
}