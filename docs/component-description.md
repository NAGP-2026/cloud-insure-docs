# Component Description Document
## InsureDocs Self-Service Document Portal – NAGP Cloud Computing Case Study

---

## 1. Amazon VPC (Virtual Private Cloud)

| Attribute | Value |
|---|---|
| CIDR | 10.0.0.0/16 |
| Region | us-east-1 |
| Availability Zones | us-east-1a, us-east-1b |

**Purpose:** Provides a logically isolated network environment for all AWS resources. All components (EC2, RDS, Lambda) reside within the VPC to prevent direct public exposure of backend systems.

**Security Considerations:**
- Three-tier subnet architecture: Public → Private App → Private DB
- Network ACLs applied at subnet level as a stateless firewall layer
- Security Groups applied at resource level as a stateful firewall layer

**High Availability:** Subnets span two Availability Zones, ensuring resilience against single-AZ failures.

---

## 2. Internet Gateway (IGW)

**Purpose:** Enables bidirectional internet connectivity for resources in Public Subnets (ALB).

**Security Considerations:** Only the ALB and NAT Gateway (conceptual) are in public subnets. EC2 instances, RDS, and Lambda are in private subnets and never directly reachable from the internet.

---

## 3. NAT Gateway *(Conceptual – depicted in diagram)*

**Purpose:** Allows resources in Private Subnets (EC2, Lambda) to initiate outbound internet connections (e.g., to download packages, reach AWS APIs) without accepting inbound internet traffic.

**Note:** NAT Gateway incurs hourly charges and is not available in the Free Tier. During this assignment, the Internet Gateway route is used as a substitute for development/testing. NAT Gateway is correctly shown in the architecture diagram.

---

## 4. Application Load Balancer (ALB)

**Purpose:** Distributes incoming HTTP traffic across multiple EC2 instances in the Auto Scaling Group across two Availability Zones.

**Security Considerations:**
- ALB Security Group allows inbound HTTP (port 80) from `0.0.0.0/0`
- Forwards traffic to EC2 targets only on port 80 (internal)
- Performs health checks on `/health` endpoint

**High Availability:** ALB spans both AZs; if all EC2 instances in one AZ fail, the ALB automatically routes traffic to the surviving AZ.

**Scalability:** ALB scales automatically to handle any traffic volume.

---

## 5. Auto Scaling Group (ASG)

**Purpose:** Automatically adjusts the number of EC2 instances based on demand — scaling out during peak business hours and scaling in during off-peak hours.

**Configuration:**
- Minimum instances: 1
- Maximum instances: 4
- Desired capacity: 2
- Scale-out policy: CPU > 70% for 2 consecutive periods
- Scale-in policy: CPU < 30% for 10 consecutive periods

**Security Considerations:** Launch Template defines the AMI, instance type, IAM Role, Security Group, and User Data script — ensuring consistent, secure configuration for every new instance.

**High Availability:** ASG distributes instances across both AZs automatically.

---

## 6. EC2 Instances (Application Servers)

| Attribute | Value |
|---|---|
| Instance type | t2.micro (Free Tier eligible) |
| OS | Amazon Linux 2023 |
| Runtime | Node.js 18 LTS |
| Application | Express.js file upload server |

**Purpose:** Hosts the InsureDocs web portal. Accepts file uploads from users and streams them directly to S3 using the AWS SDK — no temporary disk storage needed.

**Security Considerations:**
- IAM Instance Profile grants least-privilege access to S3 (PutObject only to `insurance-docs-bucket`)
- Security Group allows inbound HTTP only from the ALB Security Group (not the open internet)
- No SSH (port 22) access in production (use AWS Systems Manager Session Manager instead)

**High Availability:** Multiple instances across two AZs; ASG replaces unhealthy instances automatically.

---

## 7. Amazon S3 (Simple Storage Service)

| Attribute | Value |
|---|---|
| Bucket name | insurance-docs-bucket |
| Region | us-east-1 |
| Versioning | Enabled |
| Encryption | SSE-S3 (AES-256) |
| Public access | Blocked (all four settings) |

**Purpose:** Durable, scalable storage for all customer-uploaded documents (identity proofs, claim forms, evidence).

**Security Considerations:**
- Bucket policy denies any non-HTTPS access (`aws:SecureTransport: false` → Deny)
- Public access is fully blocked — no presigned URLs issued
- Object-level server-side encryption enforced (AES-256)
- Access only via EC2 Instance Profile (PutObject) and Lambda Execution Role (GetObject, HeadObject)
- S3 VPC Gateway Endpoint ensures S3 traffic stays within the AWS network

**High Availability:** S3 is an AWS-managed, regionally redundant service with 99.999999999% (11 nines) durability.

---

## 8. AWS Lambda

| Attribute | Value |
|---|---|
| Function name | process-uploaded-document |
| Runtime | Python 3.12 |
| Trigger | S3 PutObject (prefix: `uploads/`) |
| Memory | 256 MB |
| Timeout | 30 seconds |

**Purpose:** Serverless event-driven processor. Automatically triggered on every S3 upload; extracts metadata and records it in RDS.

**Actions:**
1. Reads object metadata using `head_object`
2. Extracts `ContentType`
3. Retrieves DB password securely from Secrets Manager
4. Inserts `file_name`, `content_type`, `upload_timestamp` into RDS
5. Logs all steps to CloudWatch Logs
6. [BONUS] Retrieves and logs keys from a demo Secrets Manager secret

**Security Considerations:**
- Lambda execution role follows least privilege (S3 HeadObject, SecretsManager GetSecretValue, RDS VPC access, CloudWatch Logs)
- Lambda runs inside the VPC in Private App Subnets to reach RDS privately
- No database credentials in code — all retrieved from Secrets Manager at runtime

**High Availability:** Lambda is fully managed and scales concurrently; AWS handles availability automatically.

---

## 9. Amazon RDS (MySQL 8.0)

| Attribute | Value |
|---|---|
| Engine | MySQL 8.0 |
| Instance class | db.t3.micro (Free Tier eligible) |
| Multi-AZ | Enabled (Standby in AZ-2) |
| Storage | 20 GB gp2, encrypted |
| Public accessibility | No |
| Subnet group | DB Private Subnets (AZ-1 + AZ-2) |

**Purpose:** Stores metadata for every uploaded document: file name, content type, and upload timestamp.

**Security Considerations:**
- Deployed in Private DB Subnets — no public IP, no route from the internet
- Security Group (`sg-rds`) allows inbound TCP:3306 **only** from the Lambda Security Group (`sg-lambda`)
- No EC2 direct access to RDS — only Lambda can connect
- Storage encryption enabled using AWS-managed key (SSE)
- Master password stored in Secrets Manager (not in any config file)

**High Availability:** Multi-AZ deployment with automatic failover; AWS performs failover within ~1–2 minutes if the primary instance fails.

---

## 10. AWS Secrets Manager

**Purpose:**
- Stores the RDS master password (`DB_SECRET_ARN`) — retrieved by Lambda at runtime
- Stores a demo/bonus secret (`SECRET_ARN`) to demonstrate Secrets Manager integration

**Security Considerations:**
- IAM policy grants Lambda execution role access only to specific secret ARNs
- Secrets are encrypted using AWS KMS
- Automatic rotation can be configured for the DB password

---

## 11. Amazon CloudWatch

**Purpose:**
- Collects Lambda execution logs (structured JSON output)
- Monitors ALB request metrics and EC2 CPU utilization for ASG scaling decisions
- [BONUS] Custom dashboard showing upload counts, Lambda duration, RDS connections
- [BONUS] Alarms: CPU > 70% (EC2), Lambda errors > 5/min, RDS connections > 80%

**Security Considerations:** Log groups are encrypted; IAM policies restrict who can read logs.

---

## 12. IAM Roles & Policies

| Role | Attached To | Key Permissions |
|---|---|---|
| `EC2InstanceRole` | EC2 via Instance Profile | `s3:PutObject` on `insurance-docs-bucket/uploads/*` |
| `LambdaExecutionRole` | Lambda | `s3:GetObject`, `s3:HeadObject`, `secretsmanager:GetSecretValue`, `rds-db:connect`, `logs:*`, `ec2:CreateNetworkInterface` (for VPC) |

**Principle of Least Privilege:** Each role grants only the minimum permissions required for its function. No `*:*` policies used anywhere.

---

## 13. Security Groups Summary

| Security Group | Resource | Inbound | Outbound |
|---|---|---|---|
| `sg-alb` | ALB | HTTP:80 from `0.0.0.0/0` | All to `sg-ec2` |
| `sg-ec2` | EC2 ASG | HTTP:80 from `sg-alb` only | HTTPS:443 to S3 endpoint |
| `sg-lambda` | Lambda | (no inbound) | MySQL:3306 to `sg-rds`, HTTPS:443 to Secrets Manager |
| `sg-rds` | RDS | MySQL:3306 from `sg-lambda` only | None |

---

## 14. Network ACLs Summary

| NACL | Applied To | Key Rules |
|---|---|---|
| `nacl-public` | Public Subnets | Inbound: Allow 80, 443, 1024-65535 (ephemeral). Outbound: Allow all |
| `nacl-private-app` | Private App Subnets | Inbound: Allow 80 from VPC CIDR, ephemeral from ALB. Outbound: Allow 3306 to DB subnets, HTTPS to S3 endpoint |
| `nacl-private-db` | Private DB Subnets | Inbound: Allow 3306 from Private App CIDR only. Outbound: Ephemeral to Private App CIDR |
