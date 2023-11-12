resource "aws_vpc" "vpc_1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "igw-pub"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  tags = {
    Name = "pubsub1"
    "kubernetes.io/cluster/eks" = "shared"
    "kuberneter.io/role/elb" = 1
  }

  map_public_ip_on_launch = true  
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "pubsub2"
    "kubernetes.io/cluster/eks" = "shared"
    "kuberneter.io/role/elb" = 1
  }

  map_public_ip_on_launch = true  
}

resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "privatesub1"
    "kubernetes.io/cluster/eks" = "shared"
    "kuberneter.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.4.0/24"

  tags = {
    Name = "privatesub2"
    "kubernetes.io/cluster/eks" = "shared"
    "kuberneter.io/role/internal-elb" = 1
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.vpc_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}



resource "aws_route_table_association" "pubsub1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table_association" "pubsub2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_security_group" "allow_web-traffic" {
  name        = "allow_web-traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_1.id

  ingress {
    description      = "https from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "allow_tls"
  }
}

resource "aws_eks_cluster" "eks" {
   name     = "eks-project"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28"
  tags = {
    "Environment" = "Development"
  }

  vpc_config {
    subnet_ids               = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    endpoint_private_access  = false
    endpoint_public_access   = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_policy_attachment
  ]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ],
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_security_group_ids" {
  value = aws_eks_cluster.eks.vpc_config[0].security_group_ids
}

resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  instance_types  = ["t2.micro"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  capacity_type = "ON_DEMAND"

  depends_on = [
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.worker_node_policy,
  ]
}

resource "aws_iam_role" "node_role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

