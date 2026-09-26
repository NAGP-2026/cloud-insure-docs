# 📋 CONTEXT FILE – InsureDocs AWS Implementation
## NAGP Cloud Computing Case Study – Resume Point

> **If conversation is lost, share this file to resume exactly where you left off.**
> Last updated: September 26, 2026

---

## 👤 AWS Account Details

| Field | Value |
|---|---|
| **AWS Account ID** | `742020474887` |
| **Root user** | Your personal email (DO NOT USE for work) |
| **Admin IAM user** | `piyush-admin` |
| **Console sign-in URL** | `https://742020474887.signin.aws.amazon.com/console` |
| **Region** | `ap-south-1` (Asia Pacific – Mumbai) |
| **MFA** | ✅ Configured on root |

---

## 📁 Project Files Location

All code and docs are at: `C:\Users\piyushchandel\cloud\`

```
cloud/
├── CONTEXT.md                          ← THIS FILE
├── README.md                           ← Project overview
├── .gitignore
├── webapp/
│   ├── app.js                          ← Node.js Express upload server
│   ├── package.json
│   └── public/index.html               ← Frontend UI
├── lambda/
│   ├── lambda_function.py              ← Python Lambda handler
│   └── requirements.txt
├── infrastructure/
│   ├── ec2-userdata.sh                 ← EC2 bootstrap script (inline app code)
│   ├── ec2-trust-policy.json
│   ├── ec2-s3-policy.json
│   ├── lambda-trust-policy.json
│   └── lambda-policy.json
└── docs/
    ├── console-step-by-step.md         ← Full AWS Console guide
    ├── architecture-diagram.md
    ├── component-description.md
    ├── deployment-guide.md
    └── scope-and-assumptions.md
```

---

## ✅ WHAT IS DONE

### AWS Console Work
- [x] Root account created + MFA enabled
- [x] IAM Admin user `piyush-admin` created with `AdministratorAccess`
- [x] Signed in as `piyush-admin` (NOT root)

### Code / Files
- [x] `webapp/app.js` – Node.js Express app (S3 upload, /health endpoint)
- [x] `webapp/public/index.html` – Drag & drop UI
- [x] `lambda/lambda_function.py` – S3→RDS metadata processor + Secrets Manager bonus
- [x] `infrastructure/ec2-userdata.sh` – Self-contained EC2 bootstrap (app embedded inline)
- [x] All IAM policy JSON files
- [x] All documentation files

---

## ⏳ WHAT IS REMAINING (IN ORDER)

### STEP 1 – IAM ✅ COMPLETE
- [x] 1A. Created IAM Group: `AlphaTeam` (user named it AlphaTeam instead of InsureDocsDevTeam)
- [x] 1B. Created IAM User: `dev-user-01` (added to AlphaTeam)
- [x] 1C. Created IAM Role: `EC2InstanceRole` (inline policy: EC2S3UploadPolicy)
- [x] 1D. Created IAM Role: `LambdaExecutionRole` (inline policy: LambdaExecutionPolicy)

### STEP 2 – VPC & Networking
- [x] 2A. Created VPC: `InsureDocs-VPC` → `vpc-032413cabb8de272b` (10.0.0.0/16)
- [x] 2B. Created Internet Gateway: `InsureDocs-IGW` (attached to InsureDocs-VPC)
- [x] 2C. Created 6 Subnets across ap-south-1a & ap-south-1b
- [x] 2D. Created Route Tables: `Public-RT` (→ IGW → public subnets) + `Private-RT` (→ IGW → private subnets)
- [x] 2E. Created 4 Security Groups: `alb-sg`, `ec2-sg`, `lambda-sg`, `rds-sg` (all in InsureDocs-VPC)
- [x] 2F. Created Network ACLs: `nacl-public` (public subnets) + `nacl-private-db` (DB subnets)

### STEP 3 – S3 Bucket ✅ COMPLETE
- [x] Created bucket: `insurance-docs-bucket-742020474887` (ap-south-1, versioning + SSE-S3)
- [x] Blocked all public access
- [x] Created `uploads/` folder

### STEP 4 – Secrets Manager ✅ COMPLETE
- [x] Created secret: `insuredocs/rds/password` → ARN: `arn:aws:secretsmanager:ap-south-1:742020474887:secret:insuredocs/rds/password-OEaBfY`
- [x] Created secret: `insuredocs/bonus-secret` → ARN: `arn:aws:secretsmanager:ap-south-1:742020474887:secret:insuredocs/bonus-secret-leecIp`

### STEP 5 – RDS MySQL ✅ COMPLETE
- [x] Created DB Subnet Group: `insuredocs-db-subnet-group`
- [x] Created RDS instance: `insuredocs-db` (MySQL 8.4.9, db.t3.micro, private, rds-sg)
- [x] RDS Endpoint: `insuredocs-db.cn6is26ysdm0.ap-south-1.rds.amazonaws.com`

### STEP 6 – Lambda ✅ COMPLETE
- [x] Created lambda_package.zip (pymysql + lambda_function.py)
- [x] Created function: `process-uploaded-document` (Python 3.14, LambdaExecutionRole)
- [x] Uploaded deployment ZIP
- [x] Configured VPC (Private-App-AZ1 + AZ2, lambda-sg)
- [x] Set 6 environment variables (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_SECRET_ARN, SECRET_ARN)
- [x] Added S3 trigger (PUT on `uploads/` prefix)

### STEP 7 – EC2 Application ✅ COMPLETE
- [x] Created Launch Template: `InsureDocs-LT` (Amazon Linux 2023, t2.micro, EC2InstanceRole, userdata)
- [x] Created Target Group: `InsureDocs-TG` (HTTP:80, /health, InsureDocs-VPC)
- [x] Created ALB: `InsureDocs-ALB` (internet-facing, Public-AZ1+AZ2, alb-sg)
- [x] Created ASG: `InsureDocs-ASG` (min:1, desired:2, max:4, CPU 70% target tracking)
- [x] ALB DNS: `InsureDocs-ALB-2063933303.ap-south-1.elb.amazonaws.com`

### STEP 8 – Verify & Test  ✅ PORTAL LIVE!
- [x] Open ALB DNS in browser → ✅ InsureDocs portal LOADING!
  - **Fix applied:** LT v5 (ec2-sg in common SGs, no custom NIC) + ASG moved to Public-AZ1+AZ2
  - ASG shows 2/2 Healthy (green) as of 12:51 AM IST Sep 27
- [ ] Upload a test file
- [ ] Check S3 for the uploaded file
- [ ] Check Lambda CloudWatch logs for execution
- [ ] Verify DB record inserted

> ⚠️ NOTE: EC2 instances now run in PUBLIC subnets (not private) due to NAT gateway limitation.
> LT is currently at version 5. Lambda is still in Private-App subnets (correct).

### STEP 9 – CloudWatch Dashboard (Bonus)
- [ ] Create dashboard: `InsureDocs-Dashboard`
- [ ] Add 4 widgets (EC2 CPU, Lambda invocations, Lambda errors, ALB requests)
- [ ] Create alarm: `InsureDocs-HighCPU` (CPU > 70%)

### STEP 10 – Clean-Up (AFTER recording demo)
- [ ] Delete ASG → ALB → TG → Launch Template
- [ ] Delete RDS (skip final snapshot)
- [ ] Empty + Delete S3 bucket
- [ ] Delete Lambda
- [ ] Delete both Secrets Manager secrets
- [ ] Delete CloudWatch log groups + dashboard
- [ ] Delete VPC (deletes subnets, SGs, NACLs, route tables, IGW)
- [ ] Delete IAM roles, policies, users, group

---

## 🔑 KEY VALUES TO FILL IN (as you complete steps)

| Resource | Value |
|---|---|
| Account ID | `742020474887` |
| Region | `ap-south-1` |
| S3 Bucket Name | `insurance-docs-bucket-742020474887` |
| RDS Endpoint | `insuredocs-db.cn6is26ysdm0.ap-south-1.rds.amazonaws.com` |
| DB Secret ARN | `arn:aws:secretsmanager:ap-south-1:742020474887:secret:insuredocs/rds/password-OEaBfY` |
| Bonus Secret ARN | `arn:aws:secretsmanager:ap-south-1:742020474887:secret:insuredocs/bonus-secret-leecIp` |
| ALB DNS Name | `InsureDocs-ALB-2063933303.ap-south-1.elb.amazonaws.com` |
| VPC ID | `vpc-032413cabb8de272b` (InsureDocs-VPC, 10.0.0.0/16) |

---

## 🛡️ Architecture (Quick Reference)

```
Internet → ALB (Public Subnets: 10.0.1.0/24, 10.0.2.0/24)
         → EC2 ASG (Private App: 10.0.11.0/24, 10.0.12.0/24)
         → S3 (insurance-docs-bucket-742020474887)
         → Lambda (triggered on S3 PutObject)
         → Secrets Manager (DB password)
         → RDS MySQL (Private DB: 10.0.21.0/24, 10.0.22.0/24)
         → CloudWatch Logs
```

### Subnet Plan

| Subnet Name | CIDR | AZ | Type |
|---|---|---|---|
| Public-AZ1 | 10.0.1.0/24 | ap-south-1a | Public |
| Public-AZ2 | 10.0.2.0/24 | ap-south-1b | Public |
| Private-App-AZ1 | 10.0.11.0/24 | ap-south-1a | Private |
| Private-App-AZ2 | 10.0.12.0/24 | ap-south-1b | Private |
| Private-DB-AZ1 | 10.0.21.0/24 | ap-south-1a | Private |
| Private-DB-AZ2 | 10.0.22.0/24 | ap-south-1b | Private |

### Security Group Rules (Quick Reference)

| SG | Inbound | From |
|---|---|---|
| sg-alb | HTTP:80 | 0.0.0.0/0 (internet) |
| sg-ec2 | HTTP:80 | sg-alb only |
| sg-lambda | none | – |
| sg-rds | MySQL:3306 | sg-lambda only |

---

## 💡 HOW TO RESUME THIS CONVERSATION

If you start a new conversation, paste this file contents and say:
> "Here is my context file for the NAGP Cloud Computing case study. I am at step [X]. Help me continue."
