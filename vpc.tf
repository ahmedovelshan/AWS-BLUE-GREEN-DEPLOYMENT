resource "aws_vpc" "devops-vpc" {
  cidr_block       = var.vpc
  instance_tenancy = "default"
}

#Create two private subnet for private resources
resource "aws_subnet" "private-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.private-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = false
  count                   = length(var.private-subnet-cidr)

  depends_on = [aws_vpc.devops-vpc]
}

#Create two public subnet for public resources like alb
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.public-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = true
  count                   = length(var.public-subnet-cidr)

  depends_on = [aws_vpc.devops-vpc]
}


#Access outside resources
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops-vpc.id

  depends_on = [aws_vpc.devops-vpc]
}


#Routing for  servers to access internet via NATGW
resource "aws_eip" "eip" {
    domain = "vpc"
    count = 2
    depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = aws_subnet.public-subnet[count.index].id
  count = 2
  tags = {
    Name = "NAT GW"
  }
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_route_table" "route-ngw" {
  count = 2
  vpc_id = aws_vpc.devops-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw[count.index].id
  }
  tags = {
    Name = "Used to access to internet via NATGW"
  }
  depends_on = [aws_nat_gateway.ngw]
}


resource "aws_route_table_association" "rt-web" {
  count =2
  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.route-ngw[count.index].id
  depends_on = [aws_route_table.route-ngw]
  
}

# Route tables for public subnets to IGW
resource "aws_route_table" "route-public" {
  vpc_id = aws_vpc.devops-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table_association" "rt-public" {
  count = 2
  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.route-public.id
  depends_on = [aws_internet_gateway.igw]
}

