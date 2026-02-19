data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true #It allows to have dns names that is important to customize adresses. 
  enable_dns_support   = true

  tags = {
    Name = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id # connect gateway with VPC

    tags = {
        Name = "${var.project_name}-igw"
    }
}

resource "aws_subnet" "public" {
    vpc_id                      = aws_vpc.main.id
    cidr_block                  = "10.0.1.0/24" # 254 addresses in the subnet
    map_public_ip_on_launch     = true #key feature to make subnet public
    availability_zone           = data.aws_availability_zones.available.names[0] 
    
    tags = {
        Name = "${var.project_name}-public-subnet"
    }
}


# Tablica Routeingu
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0" #access via internet
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name = "${var.project_name}-public-rt"
    }
}

resource "aws_route_table_association" "public" {
    subnet_id   = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}