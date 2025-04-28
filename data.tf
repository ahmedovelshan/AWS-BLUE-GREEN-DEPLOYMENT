data "aws_eks_cluster" "blue" {
  name = "blue-eks-cluster"
  depends_on = [ aws_eks_node_group.blue_eks_node_group ]
}

data "aws_security_group" "blue_eks_sg" {
  id = data.aws_eks_cluster.blue.vpc_config[0].cluster_security_group_id
  depends_on = [ aws_eks_node_group.blue_eks_node_group ]
}

output "blue_eks_cluster" {
    value = data.aws_security_group.blue_eks_sg.id
}

data "aws_caller_identity" "root" {}

# Define a local value to store the account ID
locals {
  aws_account_id = data.aws_caller_identity.root.account_id
}

# Output the AWS account ID from the local value
output "aws_account_id" {
  value = local.aws_account_id
}