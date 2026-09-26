# AWS Console – Complete Step-by-Step Implementation Guide
## InsureDocs Self-Service Document Portal

> **Follow these steps in order. Complete each section fully before moving to the next.**
> All steps are performed in AWS Region: **us-east-1 (N. Virginia)**

---

# ═══════════════════════════════════════════════
# STEP 0 – LOGIN & REGION SELECTION
# ═══════════════════════════════════════════════

1. Go to https://aws.amazon.com → click **"Sign In to the Console"**
2. Log in with your root or IAM admin account
3. In the top-right corner, click the region dropdown → select **"US East (N. Virginia) us-east-1"**

---

# ═══════════════════════════════════════════════
# STEP 1 – IAM SETUP
# ═══════════════════════════════════════════════

## 1A – Create IAM Group for Dev Team

1. In the search bar at the top, type **IAM** → click **IAM**
2. In the left sidebar, click **"User groups"**
3. Click **"Create group"**
4. **User group name:** `InsureDocsDevTeam`
5. Scroll down to **"Attach permissions policies"**
6. Search and check each of these managed policies:
   - `AmazonEC2ReadOnlyAccess`
   - `AmazonS3ReadOnlyAccess`
   - `AWSLambda_ReadOnlyAccess`
   - `AmazonRDSReadOnlyAccess`
7. Click **"Create group"**

---

## 1B – Create IAM User (Dev)

1. Left sidebar → click **"Users"**
2. Click **"Create user"**
3. **User name:** `dev-user-01`
4. Check ✅ **"Provide user access to the AWS Management Console"**
5. Select **"I want to create an IAM user"**
6. Set a password → click **"Next"**
7. Select **"Add user to group"** → check `InsureDocsDevTeam` → click **"Next"**
8. Click **"Create user"**
9. **📸 Save the sign-in URL, username, and password shown on the success screen**

---

## 1C – Create EC2 IAM Role

1. Left sidebar → click **"Roles"**
2. Click **"Create role"**
3. **Trusted entity type:** `AWS service`
4. **Use case:** select `EC2` → click **"Next"**
5. **Skip** the managed policies for now → click **"Next"**
6. **Role name:** `EC2InstanceRole`
7. Click **"Create role"**
8. In the Roles list, click **"EC2InstanceRole"**
9. Click **"Add permissions"** → **"Create inline policy"**
10. Click the **"JSON"** tab and **replace all content** with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Upload",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:PutObjectAcl"],
      "Resource": "arn:aws:s3:::insurance-docs-bucket-YOURACCOUNTID/uploads/*"
    },
    {
      "Sid": "AllowSSM",
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowCWLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

> ⚠️ Replace `YOURACCOUNTID` with your 12-digit AWS Account ID (visible in top-right → your username)

11. Click **"Next"** → **Policy name:** `EC2S3UploadPolicy` → click **"Create policy"**

---

## 1D – Create Lambda IAM Role

1. Left sidebar → **"Roles"** → **"Create role"**
2. **Trusted entity type:** `AWS service`
3. **Use case:** select `Lambda` → click **"Next"**
4. Skip managed policies → click **"Next"**
5. **Role name:** `LambdaExecutionRole`
6. Click **"Create role"**
7. Click **"LambdaExecutionRole"** from the list
8. Click **"Add permissions"** → **"Create inline policy"** → **JSON tab**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Read",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:HeadObject"],
      "Resource": "arn:aws:s3:::insurance-docs-bucket-YOURACCOUNTID/uploads/*"
    },
    {
      "Sid": "SecretsManager",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-east-1:*:secret:insuredocs/*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Sid": "VPCAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

9. Click **"Next"** → **Policy name:** `LambdaExecutionPolicy` → **"Create policy"**

---

# ═══════════════════════════════════════════════
# STEP 2 – VPC & NETWORKING
# ═══════════════════════════════════════════════

## 2A – Create VPC

1. Search bar → type **VPC** → click **VPC**
2. Left sidebar → **"Your VPCs"** → click **"Create VPC"**
3. Select **"VPC only"**
4. **Name tag:** `InsureDocs-VPC`
5. **IPv4 CIDR:** `10.0.0.0/16`
6. Leave everything else default
7. Click **"Create VPC"**
8. **After creation:** select your new VPC → click **"Actions"** → **"Edit VPC settings"**
9. ✅ Check **"Enable DNS hostnames"** → click **"Save"**

---

## 2B – Create Internet Gateway

1. Left sidebar → **"Internet gateways"** → **"Create internet gateway"**
2. **Name tag:** `InsureDocs-IGW`
3. Click **"Create internet gateway"**
4. On the next screen, click **"Attach to VPC"**
5. Select **InsureDocs-VPC** → click **"Attach internet gateway"**

---

## 2C – Create 6 Subnets

Go to **Left sidebar → "Subnets" → "Create subnet"**

Select **VPC:** `InsureDocs-VPC`

Create all 6 subnets by clicking **"Add new subnet"** for each:

| # | Name | AZ | CIDR |
|---|---|---|---|
| 1 | `Public-AZ1` | us-east-1a | 10.0.1.0/24 |
| 2 | `Public-AZ2` | us-east-1b | 10.0.2.0/24 |
| 3 | `Private-App-AZ1` | us-east-1a | 10.0.11.0/24 |
| 4 | `Private-App-AZ2` | us-east-1b | 10.0.12.0/24 |
| 5 | `Private-DB-AZ1` | us-east-1a | 10.0.21.0/24 |
| 6 | `Private-DB-AZ2` | us-east-1b | 10.0.22.0/24 |

Click **"Create subnet"** once all 6 are filled in.

**Enable auto-assign public IP for Public subnets:**
- Select `Public-AZ1` → **Actions** → **Edit subnet settings** → ✅ **Enable auto-assign public IPv4 address** → Save
- Repeat for `Public-AZ2`

---

## 2D – Create Route Tables

### Public Route Table:
1. Left sidebar → **"Route tables"** → **"Create route table"**
2. **Name:** `Public-RT` | **VPC:** `InsureDocs-VPC` → **"Create route table"**
3. Select `Public-RT` → **"Routes" tab** → **"Edit routes"** → **"Add route"**
   - **Destination:** `0.0.0.0/0`
   - **Target:** Internet Gateway → select `InsureDocs-IGW`
   - Click **"Save changes"**
4. **"Subnet associations" tab** → **"Edit subnet associations"**
   - ✅ Check `Public-AZ1` and `Public-AZ2` → **"Save associations"**

### Private Route Table:
1. **"Create route table"**
2. **Name:** `Private-RT` | **VPC:** `InsureDocs-VPC` → **"Create route table"**
3. **Routes tab** → **"Edit routes"** → **"Add route"**
   - **Destination:** `0.0.0.0/0`
   - **Target:** Internet Gateway → `InsureDocs-IGW`
   - *(In production this would be a NAT Gateway – using IGW for Free Tier)*
   - Click **"Save changes"**
4. **"Subnet associations"** → **"Edit subnet associations"**
   - ✅ Check `Private-App-AZ1`, `Private-App-AZ2`, `Private-DB-AZ1`, `Private-DB-AZ2`
   - **"Save associations"**

---

## 2E – Create Security Groups

### SG 1: ALB Security Group
1. Left sidebar → **"Security groups"** → **"Create security group"**
2. **Name:** `sg-alb` | **Description:** `ALB Security Group` | **VPC:** `InsureDocs-VPC`
3. **Inbound rules** → **"Add rule":**
   - Type: `HTTP` | Port: `80` | Source: `0.0.0.0/0`
4. Click **"Create security group"**

### SG 2: EC2 Security Group
1. **"Create security group"**
2. **Name:** `sg-ec2` | **Description:** `EC2 App Security Group` | **VPC:** `InsureDocs-VPC`
3. **Inbound rules** → **"Add rule":**
   - Type: `HTTP` | Port: `80` | Source: **Custom** → select `sg-alb`
4. Click **"Create security group"**

### SG 3: Lambda Security Group
1. **"Create security group"**
2. **Name:** `sg-lambda` | **Description:** `Lambda Security Group` | **VPC:** `InsureDocs-VPC`
3. **No inbound rules** (Lambda only makes outbound calls)
4. Click **"Create security group"**

### SG 4: RDS Security Group
1. **"Create security group"**
2. **Name:** `sg-rds` | **Description:** `RDS Security Group` | **VPC:** `InsureDocs-VPC`
3. **Inbound rules** → **"Add rule":**
   - Type: `MySQL/Aurora` | Port: `3306` | Source: **Custom** → select `sg-lambda`
4. Click **"Create security group"**

---

## 2F – Create Network ACLs

### NACL for Public Subnets:
1. Left sidebar → **"Network ACLs"** → **"Create network ACL"**
2. **Name:** `nacl-public` | **VPC:** `InsureDocs-VPC` → **"Create"**
3. Select `nacl-public` → **"Inbound rules"** tab → **"Edit inbound rules":**
   - Rule 100: Allow | TCP | Port 80 | 0.0.0.0/0
   - Rule 110: Allow | TCP | Port 443 | 0.0.0.0/0
   - Rule 120: Allow | TCP | Port 1024-65535 | 0.0.0.0/0 *(ephemeral)*
4. **"Outbound rules"** tab → **"Edit outbound rules":**
   - Rule 100: Allow | All traffic | 0.0.0.0/0
5. **"Subnet associations"** tab → **"Edit subnet associations":**
   - ✅ `Public-AZ1`, `Public-AZ2`

### NACL for Private DB Subnets:
1. **"Create network ACL"** → **Name:** `nacl-private-db` | **VPC:** `InsureDocs-VPC`
2. **Inbound rules:**
   - Rule 100: Allow | TCP | Port 3306 | 10.0.11.0/24 *(from App subnet AZ1)*
   - Rule 110: Allow | TCP | Port 3306 | 10.0.12.0/24 *(from App subnet AZ2)*
3. **Outbound rules:**
   - Rule 100: Allow | TCP | Port 1024-65535 | 10.0.11.0/24
   - Rule 110: Allow | TCP | Port 1024-65535 | 10.0.12.0/24
4. **Subnet associations:** ✅ `Private-DB-AZ1`, `Private-DB-AZ2`

---

# ═══════════════════════════════════════════════
# STEP 3 – S3 BUCKET
# ═══════════════════════════════════════════════

1. Search bar → **S3** → click **S3**
2. Click **"Create bucket"**
3. **Bucket name:** `insurance-docs-bucket-YOURACCOUNTID`
   *(Replace YOURACCOUNTID with your 12-digit account ID — must be globally unique)*
4. **AWS Region:** `US East (N. Virginia) us-east-1`
5. **"Block Public Access settings"** — ensure ALL 4 checkboxes are ✅ checked (default)
6. **"Bucket Versioning"** → click **"Enable"**
7. **"Default encryption"** → select **"Server-side encryption with Amazon S3 managed keys (SSE-S3)"**
8. Click **"Create bucket"**

**Add uploads/ folder:**
1. Click your new bucket → click **"Create folder"**
2. **Folder name:** `uploads`
3. Click **"Create folder"**

---

# ═══════════════════════════════════════════════
# STEP 4 – SECRETS MANAGER
# ═══════════════════════════════════════════════

## 4A – Create DB Password Secret

1. Search bar → **Secrets Manager** → click **Secrets Manager**
2. Click **"Store a new secret"**
3. **Secret type:** `Other type of secret`
4. Under **Key/value pairs**, add:
   - Key: `username` | Value: `admin`
   - Click **"Add row"** → Key: `password` | Value: `InsurePass#2026!`
5. Click **"Next"**
6. **Secret name:** `insuredocs/rds/password`
7. **Description:** `RDS master password for InsureDocs`
8. Click **"Next"** → **"Next"** → **"Store"**
9. 📋 **Copy the Secret ARN** — you'll need it for Lambda config

## 4B – Create Bonus Demo Secret

1. **"Store a new secret"**
2. **Secret type:** `Other type of secret`
3. Key/value:
   - Key: `app_name` | Value: `InsureDocs Portal`
   - Add row → Key: `env` | Value: `production`
4. Click **"Next"**
5. **Secret name:** `insuredocs/bonus-secret`
6. Click **"Next"** → **"Next"** → **"Store"**
7. 📋 **Copy this Secret ARN too**

---

# ═══════════════════════════════════════════════
# STEP 5 – RDS MySQL DATABASE
# ═══════════════════════════════════════════════

## 5A – Create DB Subnet Group

1. Search bar → **RDS** → click **RDS**
2. Left sidebar → **"Subnet groups"** → **"Create DB subnet group"**
3. **Name:** `insuredocs-db-subnet-group`
4. **Description:** `DB Subnet Group for InsureDocs`
5. **VPC:** `InsureDocs-VPC`
6. **Availability Zones:** select `us-east-1a` and `us-east-1b`
7. **Subnets:** select `Private-DB-AZ1` (10.0.21.0/24) and `Private-DB-AZ2` (10.0.22.0/24)
8. Click **"Create"**

## 5B – Create RDS Instance

1. Left sidebar → **"Databases"** → **"Create database"**
2. **Choose a database creation method:** `Standard create`
3. **Engine type:** `MySQL`
4. **Engine version:** `MySQL 8.0.x` (latest 8.0)
5. **Templates:** ✅ `Free tier`
6. **DB instance identifier:** `insuredocs-db`
7. **Master username:** `admin`
8. **Master password:** `InsurePass#2026!` (same as secret)
9. **Confirm password:** `InsurePass#2026!`
10. **DB instance class:** `db.t3.micro` (Free Tier)
11. **Storage:** `20 GiB` | **gp2** | ❌ Disable storage autoscaling (Free Tier)
12. **Connectivity:**
    - **VPC:** `InsureDocs-VPC`
    - **DB Subnet group:** `insuredocs-db-subnet-group`
    - **Public access:** `No`
    - **VPC security group:** click **"Choose existing"** → remove `default` → add `sg-rds`
    - **Availability Zone:** `us-east-1a`
13. **Additional configuration:**
    - **Initial database name:** `insurance_docs`
    - ✅ **Enable encryption** (AWS managed key)
    - **Backup retention:** `1 day`
14. Click **"Create database"**
    > ⏳ Wait ~5–7 minutes for status to show **"Available"**

15. Once available: click the database → copy the **Endpoint** (e.g., `insuredocs-db.xxxxxxx.us-east-1.rds.amazonaws.com`) — you'll need it for Lambda

---

# ═══════════════════════════════════════════════
# STEP 6 – LAMBDA FUNCTION
# ═══════════════════════════════════════════════

## 6A – Package Lambda Code

On your local machine (Windows CMD or PowerShell):

```cmd
cd C:\Users\piyushchandel\cloud\lambda
pip install pymysql -t .\package
copy lambda_function.py .\package\
cd package
powershell Compress-Archive -Path * -DestinationPath ..\lambda_deployment.zip -Force
cd ..
```

## 6B – Create Lambda Function in Console

1. Search bar → **Lambda** → click **Lambda**
2. Click **"Create function"**
3. Select **"Author from scratch"**
4. **Function name:** `process-uploaded-document`
5. **Runtime:** `Python 3.12`
6. **Architecture:** `x86_64`
7. **Permissions:** expand **"Change default execution role"**
   - Select **"Use an existing role"**
   - Select `LambdaExecutionRole`
8. Click **"Create function"**

## 6C – Upload Code

1. In the function page → **"Code"** tab
2. Click **"Upload from"** → **".zip file"**
3. Click **"Upload"** → select `lambda_deployment.zip` from your `lambda/` folder
4. Click **"Save"**

## 6D – Configure VPC

1. **"Configuration"** tab → **"VPC"** → **"Edit"**
2. **VPC:** `InsureDocs-VPC`
3. **Subnets:** ✅ `Private-App-AZ1` and `Private-App-AZ2`
4. **Security groups:** ✅ `sg-lambda`
5. Click **"Save"**
   > ⏳ VPC configuration takes ~1 minute

## 6E – Set Environment Variables

1. **"Configuration"** tab → **"Environment variables"** → **"Edit"**
2. Click **"Add environment variable"** for each:

| Key | Value |
|---|---|
| `DB_HOST` | *your RDS endpoint from Step 5* |
| `DB_PORT` | `3306` |
| `DB_NAME` | `insurance_docs` |
| `DB_USER` | `admin` |
| `DB_SECRET_ARN` | *ARN of `insuredocs/rds/password` from Step 4A* |
| `SECRET_ARN` | *ARN of `insuredocs/bonus-secret` from Step 4B* |

3. Click **"Save"**

## 6F – Configure Timeout and Memory

1. **"Configuration"** tab → **"General configuration"** → **"Edit"**
2. **Memory:** `256 MB`
3. **Timeout:** `0 min 30 sec`
4. Click **"Save"**

## 6G – Add S3 Trigger

1. **"Configuration"** tab → **"Triggers"** → **"Add trigger"**
2. **Source:** `S3`
3. **Bucket:** select `insurance-docs-bucket-YOURACCOUNTID`
4. **Event types:** `PUT`
5. **Prefix:** `uploads/`
6. ✅ Check **"I acknowledge..."**
7. Click **"Add"**

---

# ═══════════════════════════════════════════════
# STEP 7 – EC2 APPLICATION
# ═══════════════════════════════════════════════

## 7A – Create EC2 Launch Template

1. Search bar → **EC2** → click **EC2**
2. Left sidebar → **"Launch Templates"** → **"Create launch template"**
3. **Launch template name:** `InsureDocs-LT`
4. **Template version description:** `v1`
5. ✅ Check **"Provide guidance to help me set up a template that I can use with EC2 Auto Scaling"**
6. **Application and OS Images (AMI):** click **"Quick Start"** → select **Amazon Linux** → choose the latest **Amazon Linux 2023 AMI**
7. **Instance type:** `t2.micro`
8. **Key pair:** `Don't include in launch template` *(using SSM)*
9. **Network settings:**
   - **Subnet:** `Don't include in launch template`
   - **Security groups:** select `sg-ec2`
10. **Advanced details:**
    - **IAM instance profile:** `EC2InstanceRole`
    - **User data:** paste the entire contents of `infrastructure/ec2-userdata.sh`

    > **IMPORTANT:** In the userdata script, update line:
    > `BUCKET_NAME="insurance-docs-bucket"` → `BUCKET_NAME="insurance-docs-bucket-YOURACCOUNTID"`

11. Click **"Create launch template"**

---

## 7B – Deploy Application Files to EC2 Instances

Before creating the ASG, upload the app code to an artifact S3 bucket so EC2 instances can pull it.

### Option A – Use the same S3 bucket (simplest for demo):

Upload directly via console:
1. Go to your S3 bucket → click **"Upload"**
2. Upload `webapp/app.js`
3. Upload the `webapp/public/` folder contents into a `public/` prefix

### Option B – Embed inline in userdata (simplest):

Update the `ec2-userdata.sh` by appending the full `app.js` content directly:
1. Go to **EC2 → Launch Templates → InsureDocs-LT → Actions → Modify template (Create new version)**
2. Scroll to **User data**
3. After the `mkdir -p /opt/insuredocs` line, add `cat` heredoc blocks for `app.js` and `index.html`

---

## 7C – Create Target Group

1. Left sidebar → **"Target Groups"** → **"Create target group"**
2. **Target type:** `Instances`
3. **Target group name:** `InsureDocs-TG`
4. **Protocol:** `HTTP` | **Port:** `80`
5. **VPC:** `InsureDocs-VPC`
6. **Health checks:**
   - **Protocol:** HTTP
   - **Path:** `/health`
   - **Healthy threshold:** `2`
   - **Unhealthy threshold:** `3`
   - **Interval:** `30 seconds`
7. Click **"Next"** → **"Create target group"** *(don't register targets manually — ASG will do it)*

---

## 7D – Create Application Load Balancer

1. Left sidebar → **"Load Balancers"** → **"Create load balancer"**
2. Select **"Application Load Balancer"** → **"Create"**
3. **Load balancer name:** `InsureDocs-ALB`
4. **Scheme:** `Internet-facing`
5. **IP address type:** `IPv4`
6. **Network mapping:**
   - **VPC:** `InsureDocs-VPC`
   - **Mappings:** ✅ `us-east-1a` → select `Public-AZ1`  &  ✅ `us-east-1b` → select `Public-AZ2`
7. **Security groups:** remove `default` → add `sg-alb`
8. **Listeners and routing:**
   - Protocol: `HTTP` | Port: `80`
   - **Default action:** Forward to `InsureDocs-TG`
9. Click **"Create load balancer"**
10. 📋 Copy the **DNS name** (e.g., `InsureDocs-ALB-123456789.us-east-1.elb.amazonaws.com`)

---

## 7E – Create Auto Scaling Group

1. Left sidebar → **"Auto Scaling Groups"** → **"Create Auto Scaling group"**
2. **Auto Scaling group name:** `InsureDocs-ASG`
3. **Launch template:** `InsureDocs-LT` → **Version:** `Latest` → click **"Next"**
4. **Network:**
   - **VPC:** `InsureDocs-VPC`
   - **Availability Zones and subnets:** ✅ `Private-App-AZ1` and `Private-App-AZ2`
   - Click **"Next"**
5. **Load balancing:**
   - ✅ **"Attach to an existing load balancer"**
   - **Existing load balancer target groups:** select `InsureDocs-TG`
   - ✅ **"Turn on Elastic Load Balancing health checks"**
   - Click **"Next"**
6. **Group size and scaling:**
   - **Desired capacity:** `2`
   - **Minimum capacity:** `1`
   - **Maximum capacity:** `4`
7. **Automatic scaling:**
   - Select **"Target tracking scaling policy"**
   - **Policy name:** `CPU-Tracking-70`
   - **Metric type:** `Average CPU utilization`
   - **Target value:** `70`
   - Click **"Next"**
8. (Optional) Add notification → click **"Next"**
9. **Tags:** Key: `Name` | Value: `InsureDocs-EC2` → click **"Next"**
10. Click **"Create Auto Scaling group"**

> ⏳ ASG will launch 2 EC2 instances. Wait ~3 minutes for them to pass health checks.

---

# ═══════════════════════════════════════════════
# STEP 8 – VERIFY EVERYTHING WORKS
# ═══════════════════════════════════════════════

## 8A – Check EC2 Instances Are Healthy

1. **EC2 → Instances** — you should see 2 instances tagged `InsureDocs-EC2` in `running` state
2. **EC2 → Target Groups → InsureDocs-TG → Targets** — both instances should show `Healthy`

## 8B – Access the Application

1. Go to **EC2 → Load Balancers → InsureDocs-ALB**
2. Copy the **DNS name**
3. Open a browser → go to: `http://InsureDocs-ALB-xxxxxxxxx.us-east-1.elb.amazonaws.com`
4. You should see the **InsureDocs document upload portal** 🎉

## 8C – Upload a Test File

1. On the portal page, click **Browse** or drag & drop a file (e.g., a PDF or image)
2. Click **"Upload Document"**
3. You should see: ✅ **"File uploaded successfully to S3!"**

## 8D – Verify File in S3

1. Go to **S3 → insurance-docs-bucket-YOURACCOUNTID → uploads/**
2. You should see the uploaded file with a timestamp prefix

## 8E – Verify Lambda Executed

1. Go to **Lambda → process-uploaded-document → "Monitor" tab**
2. Click **"View CloudWatch logs"**
3. Click the latest log stream
4. You should see log entries like:
   ```
   [INFO] Lambda invoked. RequestId: ...
   [INFO] Processing s3://insurance-docs-bucket.../uploads/...
   [INFO] File metadata – Name: ... | ContentType: ... | Timestamp: ...
   [BONUS] Secret retrieved from Secrets Manager (keys only): ['app_name', 'env']
   [INFO] DB record inserted. id=1 | file=... | type=... | ts=...
   ```

## 8F – Verify RDS Database Entry

You can test the Lambda by creating a test event:
1. **Lambda → process-uploaded-document → "Test" tab**
2. Use this test event (replace values):
```json
{
  "Records": [{
    "s3": {
      "bucket": {"name": "insurance-docs-bucket-YOURACCOUNTID"},
      "object": {"key": "uploads/test-file.pdf"}
    }
  }]
}
```
3. Click **"Test"** — check execution results and CloudWatch logs

---

# ═══════════════════════════════════════════════
# STEP 9 – CLOUDWATCH DASHBOARD (BONUS)
# ═══════════════════════════════════════════════

1. Search bar → **CloudWatch** → click **CloudWatch**
2. Left sidebar → **"Dashboards"** → **"Create dashboard"**
3. **Dashboard name:** `InsureDocs-Dashboard`
4. Click **"Create dashboard"**
5. Add widgets:
   - **Widget 1:** Line chart → `EC2 → By Auto Scaling Group → CPUUtilization → InsureDocs-ASG`
   - **Widget 2:** Number → `Lambda → By Function Name → Invocations → process-uploaded-document`
   - **Widget 3:** Number → `Lambda → Errors → process-uploaded-document`
   - **Widget 4:** Number → `ApplicationELB → RequestCount → InsureDocs-ALB`
6. Click **"Save dashboard"**

### Create CloudWatch Alarm:
1. Left sidebar → **"Alarms" → "All alarms"** → **"Create alarm"**
2. **Select metric:** EC2 → Auto Scaling Groups → CPUUtilization → InsureDocs-ASG
3. **Threshold:** Greater than `70` for `2 out of 2` data points
4. **Alarm name:** `InsureDocs-HighCPU`
5. Click **"Create alarm"**

---

# ═══════════════════════════════════════════════
# STEP 10 – CLEAN-UP (AFTER DEMO RECORDING)
# ═══════════════════════════════════════════════

Delete in this order to avoid dependency errors:

1. **EC2 → Auto Scaling Groups → InsureDocs-ASG → Delete**
2. **EC2 → Load Balancers → InsureDocs-ALB → Actions → Delete**
3. **EC2 → Target Groups → InsureDocs-TG → Actions → Delete**
4. **EC2 → Launch Templates → InsureDocs-LT → Actions → Delete template**
5. **RDS → Databases → insuredocs-db → Actions → Delete** (uncheck "Create final snapshot")
6. **RDS → Subnet groups → insuredocs-db-subnet-group → Delete**
7. **S3 → insurance-docs-bucket → Empty bucket first → then Delete**
8. **Lambda → process-uploaded-document → Actions → Delete**
9. **Secrets Manager → insuredocs/rds/password → Actions → Delete secret** (7-day wait can be bypassed by setting recovery window to 0)
10. **Secrets Manager → insuredocs/bonus-secret → Delete**
11. **CloudWatch → Log groups → /aws/lambda/process-uploaded-document → Delete**
12. **CloudWatch → Dashboards → InsureDocs-Dashboard → Delete**
13. **VPC → Your VPCs → InsureDocs-VPC → Actions → Delete VPC** (this removes subnets, route tables, IGW, SGs, NACLs automatically)
14. **IAM → Roles → EC2InstanceRole → Delete** + **LambdaExecutionRole → Delete**
15. **IAM → User groups → InsureDocsDevTeam → Delete**
16. **IAM → Users → dev-user-01 → Delete**

✅ **Go to Billing → Bills to confirm $0 usage**
