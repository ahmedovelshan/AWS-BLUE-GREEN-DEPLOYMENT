resource "aws_eks_cluster" "blue_eks_cluster" {
  name     = var.blue_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = aws_subnet.blue-private-subnet[*].id
    endpoint_private_access = true
    endpoint_public_access  = false
  }
}


resource "aws_eks_node_group" "blue_eks_node_group" {
  cluster_name    = aws_eks_cluster.blue_eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.blue-private-subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t2.medium"]
}



module "eks-kubeconfig" {
  source  = "hyperbadger/eks-kubeconfig/aws"
  version = "1.0.0"

  depends_on = [aws_eks_cluster.blue_eks_cluster]
  cluster_id = aws_eks_cluster.blue_eks_cluster.id
}

resource "local_file" "kubeconfig" {
  content  = module.eks-kubeconfig.kubeconfig
  filename = "kubeconfig_${var.blue_cluster_name}"
}


