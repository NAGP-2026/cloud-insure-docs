# Architecture Diagram – InsureDocs Self-Service Portal

> **Note:** Textual representation of the cloud architecture.
> Draw in draw.io / Lucidchart using the layout below.
> **Actual deployed region:** `ap-south-1` (Mumbai)

---

## High-Level Architecture

```
                         ┌──────────────────────────────────────────────────────────────────────────┐
                         │                    AWS Region: ap-south-1 (Mumbai)                        │
                         │                                                                            │
  ┌───────────┐ HTTP:80  │  ┌──────────────────────────────────────────────────────────────────────┐ │
  │ Insurance │─────────►│  │         InsureDocs-VPC  (10.0.0.0/16)                                │ │
  │ Customers │          │  │                                                                        │ │
  └───────────┘          │  │         Internet Gateway (InsureDocs-IGW)                             │ │
        ▲                │  │                        │                                               │ │
        │                │  │  ┌─────────────────────▼────────────────────────────────────────┐     │ │
        └────────────────│  │  │          Application Load Balancer (InsureDocs-ALB)           │     │ │
                         │  │  │    Internet-facing | alb-sg | Spans AZ1 + AZ2                 │     │ │
                         │  │  └──────────┬────────────────────────────┬───────────────────────┘     │ │
                         │  │             │                            │                              │ │
                         │  │  ┌──────────▼──────────┐   ┌────────────▼──────────┐                  │ │
                         │  │  │  Public Subnet AZ1   │   │  Public Subnet AZ2    │                  │ │
                         │  │  │  10.0.1.0/24         │   │  10.0.2.0/24          │                  │ │
                         │  │  │  ap-south-1a         │   │  ap-south-1b          │                  │ │
                         │  │  │  ┌────────────────┐  │   │  ┌────────────────┐   │                  │ │
                         │  │  │  │ EC2 t3.micro   │  │   │  │ EC2 t3.micro   │   │                  │ │
                         │  │  │  │ Node.js App    │  │   │  │ Node.js App    │   │                  │ │
                         │  │  │  │ ec2-sg | :80   │  │   │  │ ec2-sg | :80   │   │                  │ │
                         │  │  │  │ [ASG managed]  │  │   │  │ [ASG managed]  │   │                  │ │
                         │  │  │  └────────────────┘  │   │  └────────────────┘   │                  │ │
                         │  │  │  ┌────────────────┐  │   │  ┌────────────────┐   │                  │ │
                         │  │  │  │ [NAT Gateway]  │  │   │  │ [NAT Gateway]  │   │                  │ │
                         │  │  │  │ (Conceptual –  │  │   │  │ (Conceptual –  │   │                  │ │
                         │  │  │  │  not deployed) │  │   │  │  not deployed) │   │                  │ │
                         │  │  │  └────────────────┘  │   │  └────────────────┘   │                  │ │
                         │  │  └──────────┬──────────┘   └──────────┬─────────────┘                  │ │
                         │  │             │                          │                                 │ │
                         │  │  ┌──────────▼──────────┐   ┌──────────▼─────────────┐                  │ │
                         │  │  │ Private App AZ1      │   │ Private App AZ2         │                  │ │
                         │  │  │ 10.0.11.0/24         │   │ 10.0.12.0/24            │                  │ │
                         │  │  │ (Lambda subnet)      │   │ (Lambda subnet)          │                  │ │
                         │  │  │ lambda-sg            │   │ lambda-sg               │                  │ │
                         │  │  └──────────┬──────────┘   └──────────┬──────────────┘                  │ │
                         │  │             └──────────┬───────────────┘                                 │ │
                         │  │                        │                                                  │ │
                         │  │  ┌─────────────────────▼─────────────────────────────────────────────┐  │ │
                         │  │  │  AWS S3 (insurance-docs-bucket-742020474887)                       │  │ │
                         │  │  │  SSE-S3 encryption | Versioning | No public access                 │  │ │
                         │  │  │  EC2 uploads via IAM role (EC2InstanceRole)                        │  │ │
                         │  │  └────────────────────────┬──────────────────────────────────────────┘  │ │
                         │  │                           │  S3 PutObject Event Trigger                  │ │
                         │  │                           │  (on uploads/ prefix)                        │ │
                         │  │  ┌────────────────────────▼──────────────────────────────────────────┐  │ │
                         │  │  │  AWS Lambda: process-uploaded-document (Python 3.14)               │  │ │
                         │  │  │  VPC: Private-App subnets | lambda-sg                              │  │ │
                         │  │  │  → Reads S3 metadata (file name, content-type, timestamp)          │  │ │
                         │  │  │  → Retrieves DB password from Secrets Manager                      │  │ │
                         │  │  │  → Retrieves bonus secret from Secrets Manager (bonus feature)     │  │ │
                         │  │  │  → Inserts record into RDS MySQL                                   │  │ │
                         │  │  │  → Writes structured logs to CloudWatch                            │  │ │
                         │  │  └────────────────────────┬──────────────────────────────────────────┘  │ │
                         │  │                           │  TCP:3306                                    │ │
                         │  │  ┌────────────────────────▼──────────────────────────────────────────┐  │ │
                         │  │  │  Private DB Subnets                                                │  │ │
                         │  │  │  AZ1: 10.0.21.0/24          AZ2: 10.0.22.0/24                    │  │ │
                         │  │  │  ┌──────────────────────────────────────────────────────────────┐ │  │ │
                         │  │  │  │  Amazon RDS MySQL 8.4.9 (db.t3.micro)                        │ │  │ │
                         │  │  │  │  insuredocs-db | No public access | rds-sg                    │ │  │ │
                         │  │  │  │  Only lambda-sg allowed on port 3306                          │ │  │ │
                         │  │  │  └──────────────────────────────────────────────────────────────┘ │  │ │
                         │  │  └───────────────────────────────────────────────────────────────────┘  │ │
                         │  │                                                                          │ │
                         │  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
                         │  │  │  Supporting Services (AWS-managed, outside VPC)                    │  │ │
                         │  │  │  • Secrets Manager: insuredocs/rds/password + insuredocs/bonus-secret│ │
                         │  │  │  • CloudWatch Logs: Lambda logs, EC2 metrics, ALB access logs     │  │ │
                         │  │  │  • CloudWatch Dashboard: InsureDocs-Dashboard                     │  │ │
                         │  │  │  • CloudWatch Alarm: InsureDocs-HighCPU (>70%)                    │  │ │
                         │  │  │  • IAM: EC2InstanceRole + LambdaExecutionRole (Least Privilege)   │  │ │
                         │  │  └───────────────────────────────────────────────────────────────────┘  │ │
                         │  └──────────────────────────────────────────────────────────────────────────┘ │
                         └──────────────────────────────────────────────────────────────────────────────┘
```

---

## Subnet Layout (Actual Deployed)

| Subnet Name | CIDR | AZ | Type | Hosts |
|---|---|---|---|---|
| Public-AZ1 | 10.0.1.0/24 | ap-south-1a | Public | ALB node, EC2 (ASG), NAT GW (conceptual) |
| Public-AZ2 | 10.0.2.0/24 | ap-south-1b | Public | ALB node, EC2 (ASG), NAT GW (conceptual) |
| Private-App-AZ1 | 10.0.11.0/24 | ap-south-1a | Private | Lambda |
| Private-App-AZ2 | 10.0.12.0/24 | ap-south-1b | Private | Lambda |
| Private-DB-AZ1 | 10.0.21.0/24 | ap-south-1a | Private | RDS MySQL |
| Private-DB-AZ2 | 10.0.22.0/24 | ap-south-1b | Private | RDS MySQL standby |

---

## Security Group Rules

| Security Group | Inbound Rule | Source | Purpose |
|---|---|---|---|
| `alb-sg` | HTTP:80 | 0.0.0.0/0 | Accept internet traffic |
| `ec2-sg` | HTTP:80 | alb-sg | Only ALB can reach EC2 |
| `ec2-sg` | SSH:22 | 0.0.0.0/0 | Temporary debug (remove after) |
| `lambda-sg` | (none inbound) | – | Lambda initiates outbound only |
| `rds-sg` | MySQL:3306 | lambda-sg | Only Lambda can reach RDS |

---

## Network ACL Rules

| NACL | Applied To | Inbound | Outbound |
|---|---|---|---|
| `nacl-public` | Public subnets | Allow HTTP:80, HTTPS:443, ephemeral | Allow all |
| `nacl-private-db` | DB subnets | Allow MySQL:3306 from 10.0.0.0/16 | Allow ephemeral |
| Default NACL | App subnets | Allow all (default) | Allow all |

---

## Traffic Flow

```
1. Customer Browser → HTTP:80 → IGW → ALB (Public Subnet)
2. ALB → HTTP:80 → EC2 ASG instance (Public Subnet, ec2-sg)
3. EC2 → AWS SDK → S3 (via IAM role, SSE-S3 encrypted)
4. S3 PutObject → Lambda trigger (uploads/ prefix)
5. Lambda → Secrets Manager → retrieve DB password + bonus secret
6. Lambda → TCP:3306 → RDS MySQL (Private DB Subnet)
7. Lambda → CloudWatch Logs (structured output)
8. ASG → scales EC2 between 1–4 instances based on CPU (70% threshold)
```

---

## Auto Scaling Configuration

| Setting | Value |
|---|---|
| Min instances | 1 |
| Desired instances | 2 |
| Max instances | 4 |
| Scaling policy | Target Tracking – CPU 70% |
| Health check | ELB (ALB health check on /health) |
| Multi-AZ | ✅ ap-south-1a + ap-south-1b |

---

## NAT Gateway Note

Per assignment requirement: NAT Gateway is **shown in the architecture diagram** above (in Public Subnets, one per AZ) but **not deployed** in the actual AWS setup. Reason: NAT Gateway costs ~$32/month per gateway, which exceeds Free Tier limits. EC2 instances are placed in Public subnets with IGW access as a Free Tier workaround. This is documented in Scope & Assumptions.
