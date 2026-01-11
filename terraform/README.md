Terraform

How terraform is making the ECS EC2 Cluster is explained below

1. First of all, it will setup VPC
2. Application Load Balance (ALB) is created for public access
3. Private subnet is created for internal communication through ports
4. Security group is created for public ALB
5. Allow ECS access to DB
6. ECS EC2 Cluster is created
