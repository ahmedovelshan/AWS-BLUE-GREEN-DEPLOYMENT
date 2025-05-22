data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_network_interface" "web-ec2-network" {
  subnet_id       = aws_subnet.blue-public-subnet[count.index].id
  count           = length(var.blue-public-subnet-cidr)
  security_groups = [aws_security_group.ci-cd-tools.id]
}



resource "aws_instance" "ci-cd-tools" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.large"
  availability_zone = "eu-central-1a"
  root_block_device {
    delete_on_termination = true
    volume_size           = 20
  }
  count      = 1
  depends_on = [aws_eks_node_group.blue_eks_node_group]

  network_interface {
    network_interface_id = aws_network_interface.web-ec2-network[count.index].id
    device_index         = 0
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system and install essential tools
    sudo apt-get update && sudo apt-get install -y \
      openjdk-17-jre-headless \
      ca-certificates \
      curl \
      unzip

    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
    sudo apt-get update -y && sudo apt-get install -y jenkins
    sudo systemctl restart jenkins

    # Install Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update && sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
    ec2_username=$(awk -F: '$3 == 1000 { print $1; exit }' /etc/passwd)
    sudo usermod -aG docker $ec2_username

    # Run Nexus
    sudo docker run -d --name nexus -p 8081:8081 sonatype/nexus3:latest

    # Run SonarQube
    sudo docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

    # Install Terraform
    sudo snap install terraform --classic

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    aws --version

    # Install kubectl CLI
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install eksctl CLI
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin

    # Install Trivy
    wget https://github.com/aquasecurity/trivy/releases/download/v0.43.0/trivy_0.43.0_Linux-64bit.deb
    sudo dpkg -i trivy_0.43.0_Linux-64bit.deb

    #Connect to AWS EKS Cluster
    aws configure set aws_access_key_id "${var.aws_access_key}" && aws configure set aws_secret_access_key "${var.aws_secret_key}" && aws configure set region "${var.region_name}"
    aws eks update-kubeconfig --region "${var.region_name}" --name "${var.blue_cluster_name}"


    #Install IAM OIDC provider for your EKS cluster
    eksctl utils associate-iam-oidc-provider \
    --region "${var.region_name}" \
    --cluster "${var.blue_cluster_name}" \
    --approve


    echo "Waiting for OIDC provider to be ready..."
    for i in {1..10}; do
      if aws eks describe-cluster --region ${var.region_name} --name ${var.blue_cluster_name} --query "cluster.identity.oidc.issuer" --output text | grep -q "https://"; then
        echo "OIDC provider is ready."
        break
      else
        echo "OIDC provider not ready yet. Sleeping 10s..."
        sleep 10
      fi
    done

    eksctl create iamserviceaccount \
    --cluster="${var.blue_cluster_name}" \
    --namespace=kube-system \
    --name=blue-aws-load-balancer-controller \
    --attach-policy-arn="arn:aws:iam::${local.aws_account_id}:policy/AWSLoadBalancerControllerIAMPolicy" \
    --override-existing-serviceaccounts \
    --approve


EOF
}



