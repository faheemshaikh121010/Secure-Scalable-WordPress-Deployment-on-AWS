Architectur Diagram:

+----------------------------------------------------------------------------------------+
|                                   AWS Region (us-east-1)                                |
|                                                                                        |
|  +---------------------------------------+          +--------------------------------+ |
|  |               Public Subnet           |          |        Private Subnet          | |
|  |  +----------------+  +-------------+  |          |  +----------+  +------------+ | |
|  |  |  NAT Gateway   |  | Application |  |          |  |  RDS     |  | EFS Mount  | | |
|  |  |                |  | Load Balancer| <----+     |  | (MySQL)  |  | Targets    | | |
|  |  +----------------+  +-------------+  |     |     |  +----------+  +------------+ | |
|  |                                       |     |     |                              | |
|  +---------------------------------------+     |     +------------------------------+ |
|            |                                    |                                    |
|            |                                    |                                    |
|  +---------v--------+                  +--------v---------+                          |
|  | Auto Scaling     |                  | EC2 Instances    |                          |
|  | Group (ASG)      |                  | (Private Subnet) |                          |
|  | - Launch Template|                  | - WordPress      |                          |
|  | - Min: 2, Max: 6|                  | - Nginx/PHP     |                          |
|  +------------------+                  +------------------+                          |
|            | Mounts EFS                                                              |
|  +---------v---------+                                                               |
|  | Elastic File      |                                                               |
|  | System (EFS)      |                                                               |
|  | - Encrypted       |                                                               |
|  +-------------------+                                                               |
+----------------------------------------------------------------------------------------+


Component Descriptions
1. VPC & Networking
VPC: 10.0.0.0/16 with public/private subnets across 2 AZs.

Public Subnets: Host ALB and NAT Gateway.

Private Subnets: Host EC2 instances, RDS, and EFS.

NAT Gateway: Allows private subnets to access the internet.

Route Tables:

Public route to Internet Gateway (IGW).

Private route to NAT Gateway.

2. Compute Layer
EC2 Auto Scaling Group (ASG):

Min/Max Instances: 2/6 (t3.micro).

Launch Template: Uses Amazon Linux 2023 AMI, mounts EFS at boot.

User Data: Automates WordPress installation and configures Nginx.

Application Load Balancer (ALB):

Distributes traffic across EC2 instances.

Listens on HTTP (port 80).

3. Storage
RDS (MySQL):

Multi-AZ: Enabled for high availability.

Encrypted: AES-256 using AWS KMS.

Security: Access restricted to EC2 security group.

EFS:

Shared storage for WordPress files.

Mounted on EC2 instances at /var/www/html.

4. Security
Security Groups:

ALB: Allows HTTP (port 80) from anywhere.

EC2: Allows HTTP (port 80) from ALB and SSH (port 22) from your IP.

RDS: Allows MySQL (port 3306) from EC2 instances.

EFS: Allows NFS (port 2049) from EC2 instances.

IAM Roles:

EC2 instances use least-privilege roles for EFS/Secrets Manager access.

5. Monitoring & Logging
CloudWatch:

Monitors EC2 CPU, RDS connections, ALB request count.

Alarms trigger ASG scaling policies.

Enhanced Monitoring:

Enabled for RDS.
