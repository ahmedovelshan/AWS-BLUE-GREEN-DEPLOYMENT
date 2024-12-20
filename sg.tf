
resource "aws_security_group" "alb-sg" {
    vpc_id              = aws_vpc.devops-vpc.id
    name                = "www-to-alb"
    description         = "Access from WWW to ALB"
    dynamic "ingress" {
        for_each = var.alb-port
        content {
          protocol = "tcp"
          from_port = ingress.value
          to_port = ingress.value
          cidr_blocks = [ "0.0.0.0/0" ]
        }      
    }
    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = [ "0.0.0.0/0" ]
    }
}


resource "aws_security_group" "private-sg" {
    vpc_id              = aws_vpc.devops-vpc.id
    name                = "alb-to-web"
    description         = "Access from ALB to WEB subnet"
    dynamic "ingress" {
        for_each = var.eks-ec2-port
        content {
          protocol = "tcp"
          from_port = ingress.value
          to_port = ingress.value
          cidr_blocks = var.private-subnet-cidr
        }     
    }
    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = [ "0.0.0.0/0" ]
    }
}


resource "aws_security_group" "ci-cd-tools" {
    vpc_id              = aws_vpc.devops-vpc.id
    name                = "ci-cd-tools"
    description         = "Access from CI/CD tools"
    dynamic "ingress" {
        for_each = var.ci-cd-tool-port
        content {
          protocol = "tcp"
          from_port = ingress.value
          to_port = ingress.value
          cidr_blocks = [ "0.0.0.0/0" ]
        }     
    }
    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = [ "0.0.0.0/0" ]
    }
}