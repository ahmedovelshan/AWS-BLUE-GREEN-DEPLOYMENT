resource "aws_vpc" "devops-vpc" {
  cidr_block       = var.vpc
  instance_tenancy = "default"
}

#Create private subnets for private resources like AWS EKS
resource "aws_subnet" "blue-private-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.blue-private-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = false
  enable_resource_name_dns_a_record_on_launch = true
  count                   = length(var.blue-private-subnet-cidr)
  tags = {
    Name = "blue-private-subnet-${count.index + 1}"
    Environment = "blue"
  } 
}

resource "aws_subnet" "green-private-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.green-private-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = false
  enable_resource_name_dns_a_record_on_launch = true
  count                   = length(var.green-private-subnet-cidr)
  tags = {
    Name = "green-private-subnet-${count.index + 1}"
    Environment = "green"
  } 
}



#Create public subnets for public resources like alb, CI/CD tools
resource "aws_subnet" "blue-public-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.blue-public-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = true
  enable_resource_name_dns_a_record_on_launch = true
  count                   = length(var.blue-public-subnet-cidr)
  tags = {
    Name = "blue-public-subnet-${count.index + 1}"
    Environment = "blue"
  } 
}


resource "aws_subnet" "green-public-subnet" {
  vpc_id                  = aws_vpc.devops-vpc.id
  cidr_block              = element(var.green-public-subnet-cidr, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = true
  enable_resource_name_dns_a_record_on_launch = true
  count                   = length(var.green-public-subnet-cidr)
  tags = {
    Name = "green-public-subnet-${count.index + 1}"
    Environment = "green"
  } 
}


#Access outside resources
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops-vpc.id
}


#Routing for  resoursec to access internet via NATGW (Blue enviroment)
resource "aws_eip" "blue-eip" {
    domain = "vpc"
    count = length(var.blue-private-subnet-cidr)
}

resource "aws_nat_gateway" "blue-ngw" {
  allocation_id = aws_eip.blue-eip[count.index].id
  count = length(var.blue-private-subnet-cidr)
  subnet_id     = aws_subnet.blue-public-subnet[count.index].id
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_route_table" "blue-route-ngw" {
  vpc_id = aws_vpc.devops-vpc.id
  count = length(var.blue-private-subnet-cidr)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.blue-ngw[count.index].id
  }
}


resource "aws_route_table_association" "blue-rt-web" {
  count          = length(var.blue-private-subnet-cidr)
  subnet_id      = aws_subnet.blue-private-subnet[count.index].id
  route_table_id = aws_route_table.blue-route-ngw[count.index].id
  
}

#Routing for  resoursec to access internet via NATGW (Green  enviroment)
resource "aws_eip" "green-eip" {
    domain = "vpc"
    count = length(var.green-private-subnet-cidr)
}

resource "aws_nat_gateway" "green-ngw" {
  allocation_id = aws_eip.green-eip[count.index].id
  count = length(var.green-private-subnet-cidr)
  subnet_id     = aws_subnet.green-public-subnet[count.index].id
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_route_table" "green-route-ngw" {
  vpc_id = aws_vpc.devops-vpc.id
  count = length(var.green-private-subnet-cidr)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.green-ngw[count.index].id
  }
}


resource "aws_route_table_association" "green-rt-web" {
  count          = length(var.green-private-subnet-cidr)
  subnet_id      = aws_subnet.green-private-subnet[count.index].id
  route_table_id = aws_route_table.green-route-ngw[count.index].id  
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

resource "aws_route_table_association" "blue-rt-public" {
  count          = length(var.blue-public-subnet-cidr)
  subnet_id      = aws_subnet.blue-public-subnet[count.index].id
  route_table_id = aws_route_table.route-public.id
  depends_on     = [aws_internet_gateway.igw]
}

resource "aws_route_table_association" "green-rt-public" {
  count          = length(var.green-public-subnet-cidr)
  subnet_id      = aws_subnet.green-public-subnet[count.index].id
  route_table_id = aws_route_table.route-public.id
  depends_on     = [aws_internet_gateway.igw]
}

