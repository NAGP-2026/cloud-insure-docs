# 🎬 Walkthrough Script — AWS Configuration (8 Minutes)
## InsureDocs Self-Service Portal — NAGP Cloud Computing Case Study

> **Instructions:** Read each sentence while showing the corresponding AWS Console screen.
> Speak clearly and at a steady pace. Each section has a time budget.

---

### [0:00 – 0:10] Introduction

**ACTION:** Show AWS Console home page

**SAY:**
> "In this walkthrough, I will demonstrate the complete AWS infrastructure setup for the InsureDocs Self-Service Document Upload Portal — built for the NAGP Cloud Computing case study.
> All resources are deployed in the ap-south-1 — Mumbai region, using Free Tier eligible services wherever possible."

---

### [0:10 – 1:10] PART 1: IAM Setup

**ACTION:** Navigate to IAM → Users

**SAY:**
> "Let's start with Identity and Access Management — IAM.
> I have created IAM users for the development team.
> Here you can see the dev team user created for this project."

**ACTION:** Click on the user → show Groups tab

**SAY:**
> "The user belongs to the dev-team group.
> By assigning permissions at the group level, we follow the Principle of Least Privilege — users inherit only what the group needs."

**ACTION:** Navigate to IAM → Roles → show EC2InstanceRole

**SAY:**
> "I created two IAM roles.
> The first is EC2InstanceRole — attached to our EC2 instances via an Instance Profile.
> Its policy allows only S3 PutObject on the uploads prefix of our specific bucket — nothing else."

**ACTION:** Navigate to IAM → Roles → show LambdaExecutionRole

**SAY:**
> "The second role is LambdaExecutionRole — attached to our Lambda function.
> It allows Lambda to write CloudWatch logs, connect to the VPC, retrieve secrets from Secrets Manager, and access RDS — all scoped to minimum required resources only."

---

### [1:10 – 2:40] PART 2: VPC & Network Setup

**ACTION:** Navigate to VPC → Your VPCs → click InsureDocs-VPC

**SAY:**
> "Now let's look at the network architecture.
> I created a custom VPC called InsureDocs-VPC with CIDR block 10.0.0.0 slash 16.
> All resources are deployed inside this isolated network."

**ACTION:** Navigate to VPC → Subnets → filter by InsureDocs-VPC

**SAY:**
> "The VPC contains six subnets across two Availability Zones — ap-south-1a and ap-south-1b.
> Two public subnets host the Application Load Balancer and EC2 instances.
> Two private application subnets host the Lambda function.
> Two private database subnets host the RDS MySQL instance.
> This three-tier architecture ensures that backend systems are never directly exposed to the internet."

**ACTION:** Navigate to VPC → Internet Gateways → show InsureDocs-IGW

**SAY:**
> "The Internet Gateway provides inbound and outbound internet connectivity for resources in the public subnets.
> In a production setup, private subnets would use a NAT Gateway for outbound-only internet access — this is shown in our architecture diagram — however, NAT Gateway is not available on the Free Tier, so we used the IGW as a workaround for this assignment."

**ACTION:** Navigate to VPC → Route Tables → show Public-RT

**SAY:**
> "The public route table has a default route to the Internet Gateway for outbound internet traffic."

**ACTION:** Navigate to VPC → Network ACLs

**SAY:**
> "Network ACLs provide a stateless firewall at the subnet level.
> The public NACL allows HTTP on port 80, HTTPS on port 443, and ephemeral ports.
> The private DB NACL restricts traffic to only MySQL port 3306 from the private application subnets."

---

### [2:40 – 3:40] PART 3: Security Groups

**ACTION:** Navigate to VPC → Security Groups → show alb-sg

**SAY:**
> "Security groups act as stateful firewalls at the resource level.
> The ALB security group allows inbound HTTP on port 80 from anywhere — 0.0.0.0/0 — since users access it from the internet."

**ACTION:** Click ec2-sg

**SAY:**
> "The EC2 security group allows HTTP on port 80 only from the ALB security group — not from the open internet.
> This ensures traffic always passes through the load balancer first."

**ACTION:** Click lambda-sg

**SAY:**
> "The Lambda security group has no inbound rules — Lambda is never directly called from outside.
> It only makes outbound connections to the RDS database."

**ACTION:** Click rds-sg

**SAY:**
> "The RDS security group allows MySQL on port 3306 only from the Lambda security group.
> This means only our Lambda function can communicate with the database — no EC2, no internet access."

---

### [3:40 – 5:10] PART 4: EC2, Launch Template, ASG & ALB

**ACTION:** Navigate to EC2 → Launch Templates → click InsureDocs-LT

**SAY:**
> "Let's look at the compute setup.
> I created a Launch Template called InsureDocs-LT.
> It defines the Amazon Machine Image — Amazon Linux 2023, the instance type — t3.micro, the IAM Instance Profile, the security group, and the User Data bootstrap script."

**ACTION:** Show User Data tab (briefly)

**SAY:**
> "The User Data script automatically installs Node.js, downloads the application from S3, and starts the web server when a new EC2 instance launches — making every new instance identical and ready to serve traffic within minutes."

**ACTION:** Navigate to EC2 → Auto Scaling Groups → InsureDocs-ASG

**SAY:**
> "The Auto Scaling Group uses this Launch Template.
> It maintains a minimum of 1 instance, a desired capacity of 2, and can scale up to 4 instances.
> Instances are distributed across both Availability Zones for high availability."

**ACTION:** Show Automatic Scaling tab → Target Tracking policy

**SAY:**
> "The scaling policy uses CPU utilization as the trigger.
> When CPU exceeds 70 percent, new instances are automatically launched.
> When load drops below 30 percent, excess instances are terminated.
> This handles peak traffic during business hours and reduces cost during off-peak hours."

**ACTION:** Navigate to EC2 → Load Balancers → InsureDocs-ALB

**SAY:**
> "The Application Load Balancer distributes incoming HTTP traffic across EC2 instances in both Availability Zones.
> The target group performs health checks on the slash health endpoint every 30 seconds.
> If an instance becomes unhealthy, the ALB automatically stops sending traffic to it."

---

### [5:10 – 5:40] PART 5: S3 Bucket

**ACTION:** Navigate to S3 → insurance-docs-bucket-742020474887 → Properties tab

**SAY:**
> "Amazon S3 is used to store all uploaded documents.
> Versioning is enabled — so every version of every file is preserved.
> Server-side encryption using AES-256 is applied to all objects automatically."

**ACTION:** Show Permissions tab → Block public access settings

**SAY:**
> "All four public access settings are blocked — the bucket is completely private.
> Access is granted only to the EC2 role for uploads and the Lambda role for reading metadata."

**ACTION:** Show Properties → Event Notifications

**SAY:**
> "An S3 event notification is configured to trigger the Lambda function whenever a file is uploaded with the uploads/ prefix."

---

### [5:40 – 6:40] PART 6: Lambda Function

**ACTION:** Navigate to Lambda → process-uploaded-document → Configuration tab

**SAY:**
> "The Lambda function is called process-uploaded-document.
> It runs Python 3.14, with 128 megabytes of memory and a 30-second timeout.
> It is deployed inside the VPC — in the private application subnets — so it can privately reach the RDS database."

**ACTION:** Show Environment Variables tab

**SAY:**
> "The function uses environment variables for all configuration — DB host, port, database name, username, and password.
> Storing the password as an environment variable avoids hardcoding credentials in the source code."

**ACTION:** Show Triggers tab

**SAY:**
> "The trigger is the S3 bucket — specifically the ObjectCreated event on the uploads prefix.
> Every file upload automatically invokes this function."

**ACTION:** Show Monitor tab → View CloudWatch Logs button

**SAY:**
> "We can monitor Lambda executions in CloudWatch.
> The function extracts the file content type using Python's mimetypes library, inserts the record into RDS, and logs the result — as we saw in the demo."

---

### [6:40 – 7:10] PART 7: RDS Database

**ACTION:** Navigate to RDS → Databases → insuredocs-db

**SAY:**
> "The Amazon RDS instance runs MySQL version 8.4.9 on a db.t3.micro instance — which is Free Tier eligible.
> It is deployed in the private database subnets with no public accessibility — it cannot be reached from the internet."

**ACTION:** Show Connectivity & Security tab → show VPC, Subnets, Security Group

**SAY:**
> "The database is associated with the RDS security group which allows connections only from the Lambda security group on port 3306.
> This enforces the requirement that only Lambda can communicate with the database — not EC2, not developers directly."

---

### [7:10 – 7:50] PART 8: CloudWatch Dashboard & Alarm

**ACTION:** Navigate to CloudWatch → Dashboards → InsureDocs-Dashboard

**SAY:**
> "For observability, I created a CloudWatch Dashboard called InsureDocs-Dashboard.
> It shows four widgets — EC2 CPU utilization from the Auto Scaling Group, ALB request count broken down by Availability Zone, Lambda invocations, and Lambda errors.
> This gives a single-pane view of the entire system's health."

**ACTION:** Navigate to CloudWatch → All Alarms → InsureDocs-HighCPU

**SAY:**
> "I also created a CloudWatch Alarm called InsureDocs-HighCPU.
> It monitors the CPU utilization of the Auto Scaling Group.
> When CPU exceeds 70 percent for 5 minutes, it sends an email notification via Amazon SNS to the InsureDocs-Alerts topic.
> This provides proactive alerting when the application is under high load."

---

### [7:50 – 8:00] Closing

**ACTION:** Show AWS Console home or architecture diagram

**SAY:**
> "This completes the AWS configuration walkthrough for the InsureDocs portal.
> The infrastructure covers all required components — VPC, security, EC2 with Auto Scaling, S3, Lambda, RDS, and CloudWatch — following cloud architecture best practices for security, scalability, high availability, and cost optimization.
> Thank you."

---

> ✅ Total time: ~8 minutes
>
> **Key design decisions to mention during walkthrough:**
> - Least Privilege IAM: each role has the minimum required permissions
> - Security Group chaining: ec2-sg ← alb-sg, rds-sg ← lambda-sg
> - NAT Gateway depicted but not deployed (Free Tier constraint)
> - EC2 in public subnets as NAT Gateway workaround
> - Lambda in VPC private subnets to reach RDS internally
> - DB password as env var (Secrets Manager call gracefully handled with 3s timeout)
> - Single-AZ RDS (Free Tier) — Multi-AZ recommended for production
