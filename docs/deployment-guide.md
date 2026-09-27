# Deployment Guide
## InsureDocs Self-Service Document Portal – NAGP Cloud Computing Case Study

---

## Prerequisites

- AWS Account (Free Tier eligible)
- AWS CLI v2 installed and configured (`aws configure`)
- Node.js ≥ 18 (for local testing only)
- Python 3.12 (for local Lambda testing)
- Git

---

## PART 1 – IAM Setup

### Step 1.1 – Create Dev Team IAM Group

```bash
# Create IAM group for developers
aws iam create-group --group-name InsureDocsDevTeam

# Attach managed policies (least privilege set)
aws iam attach-group-policy \
  --group-name InsureDocsDevTeam \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess

aws iam attach-group-policy \
  --group-name InsureDocsDevTeam \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

aws iam attach-group-policy \
  --group-name InsureDocsDevTeam \
  --policy-arn arn:aws:iam::aws:policy/AWSLambda_ReadOnlyAccess
```

### Step 1.2 – Create IAM Users

```bash
# Create a developer user
aws iam create-user --user-name dev-user-01

# Add user to group
aws iam add-user-to-group \
  --user-name dev-user-01 \
  --group-name InsureDocsDevTeam

# Create programmatic access key
aws iam create-access-key --user-name dev-user-01
# Save the AccessKeyId and SecretAccessKey securely!
```

### Step 1.3 – Create EC2 Instance Role

```bash
# Create the role with EC2 trust policy
aws iam create-role \
  --role-name EC2InstanceRole \
  --assume-role-policy-document file://infrastructure/ec2-trust-policy.json

# Attach the custom S3 upload policy
aws iam put-role-policy \
  --role-name EC2InstanceRole \
  --policy-name S3UploadPolicy \
  --policy-document file://infrastructure/ec2-s3-policy.json

# Create instance profile and attach role
aws iam create-instance-profile --instance-profile-name EC2InstanceProfile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2InstanceProfile \
  --role-name EC2InstanceRole
```

### Step 1.4 – Create Lambda Execution Role

```bash
aws iam create-role \
  --role-name LambdaExecutionRole \
  --assume-role-policy-document file://infrastructure/lambda-trust-policy.json

aws iam put-role-policy \
  --role-name LambdaExecutionRole \
  --policy-name LambdaExecutionPolicy \
  --policy-document file://infrastructure/lambda-policy.json
```

---

## PART 2 – Networking Setup

### Step 2.1 – Create VPC

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=InsureDocs-VPC}]' \
  --query 'Vpc.VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
```

### Step 2.2 – Create Subnets

```bash
# Public Subnet AZ-1
PUB1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public-AZ1}]' \
  --query 'Subnet.SubnetId' --output text)

# Public Subnet AZ-2
PUB2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public-AZ2}]' \
  --query 'Subnet.SubnetId' --output text)

# Private App Subnet AZ-1
APP1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-App-AZ1}]' \
  --query 'Subnet.SubnetId' --output text)

# Private App Subnet AZ-2
APP2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.12.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-App-AZ2}]' \
  --query 'Subnet.SubnetId' --output text)

# Private DB Subnet AZ-1
DB1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.21.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-DB-AZ1}]' \
  --query 'Subnet.SubnetId' --output text)

# Private DB Subnet AZ-2
DB2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.22.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-DB-AZ2}]' \
  --query 'Subnet.SubnetId' --output text)

echo "Subnets created: $PUB1 $PUB2 $APP1 $APP2 $DB1 $DB2"
```

### Step 2.3 – Internet Gateway

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=InsureDocs-IGW}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "IGW: $IGW_ID"
```

### Step 2.4 – Route Tables

```bash
# Public Route Table
PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Public-RT}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $PUB_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

aws ec2 associate-route-table --subnet-id $PUB1 --route-table-id $PUB_RT
aws ec2 associate-route-table --subnet-id $PUB2 --route-table-id $PUB_RT

# Private Route Table (using IGW instead of NAT GW – demo only)
PRIV_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Private-RT}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $PRIV_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

aws ec2 associate-route-table --subnet-id $APP1 --route-table-id $PRIV_RT
aws ec2 associate-route-table --subnet-id $APP2 --route-table-id $PRIV_RT
aws ec2 associate-route-table --subnet-id $DB1  --route-table-id $PRIV_RT
aws ec2 associate-route-table --subnet-id $DB2  --route-table-id $PRIV_RT
```

### Step 2.5 – Security Groups

```bash
# ALB Security Group
SG_ALB=$(aws ec2 create-security-group \
  --group-name sg-alb --description "ALB Security Group" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ALB \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# EC2 Security Group
SG_EC2=$(aws ec2 create-security-group \
  --group-name sg-ec2 --description "EC2 App Security Group" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_EC2 \
  --protocol tcp --port 80 --source-group $SG_ALB

# Lambda Security Group
SG_LAMBDA=$(aws ec2 create-security-group \
  --group-name sg-lambda --description "Lambda Security Group" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# RDS Security Group
SG_RDS=$(aws ec2 create-security-group \
  --group-name sg-rds --description "RDS Security Group" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_RDS \
  --protocol tcp --port 3306 --source-group $SG_LAMBDA

echo "Security Groups – ALB:$SG_ALB EC2:$SG_EC2 Lambda:$SG_LAMBDA RDS:$SG_RDS"
```

---

## PART 3 – S3 Bucket

```bash
# Create bucket (replace YOUR_ACCOUNT_ID with your actual account ID)
aws s3api create-bucket \
  --bucket insurance-docs-bucket-YOUR_ACCOUNT_ID \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Block all public access
aws s3api put-public-access-block \
  --bucket insurance-docs-bucket-YOUR_ACCOUNT_ID \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket insurance-docs-bucket-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Enable default encryption (AES256)
aws s3api put-bucket-encryption \
  --bucket insurance-docs-bucket-YOUR_ACCOUNT_ID \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

---

## PART 4 – RDS MySQL

### Step 4.1 – Create DB Subnet Group

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name insuredocs-db-subnet-group \
  --db-subnet-group-description "DB Subnet Group for InsureDocs" \
  --subnet-ids $DB1 $DB2
```

### Step 4.2 – Store DB Password in Secrets Manager

```bash
aws secretsmanager create-secret \
  --name insuredocs/rds/password \
  --description "RDS master password for InsureDocs" \
  --secret-string '{"username":"admin","password":"YOUR_STRONG_PASSWORD_HERE"}'
```

### Step 4.3 – Create RDS Instance

```bash
aws rds create-db-instance \
  --db-instance-identifier insuredocs-db \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --engine-version 8.0 \
  --master-username admin \
  --master-user-password YOUR_STRONG_PASSWORD_HERE \
  --allocated-storage 20 \
  --storage-type gp2 \
  --storage-encrypted \
  --db-subnet-group-name insuredocs-db-subnet-group \
  --vpc-security-group-ids $SG_RDS \
  --no-publicly-accessible \
  --db-name insurance_docs \
  --backup-retention-period 1

# Wait for DB to become available (takes ~5 minutes)
aws rds wait db-instance-available \
  --db-instance-identifier insuredocs-db

# Get the endpoint
aws rds describe-db-instances \
  --db-instance-identifier insuredocs-db \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

---

## PART 5 – Lambda Deployment

### Step 5.1 – Create Lambda Deployment Package

```bash
cd lambda

# Install dependencies into a package directory
pip install -r requirements.txt -t ./package

# Copy the function code
cp lambda_function.py ./package/

# Create the ZIP
cd package
zip -r ../lambda_deployment.zip .
cd ..
```

### Step 5.2 – Create Lambda Function

```bash
LAMBDA_ROLE_ARN=$(aws iam get-role \
  --role-name LambdaExecutionRole \
  --query 'Role.Arn' --output text)

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier insuredocs-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)

DB_SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id insuredocs/rds/password \
  --query 'ARN' --output text)

aws lambda create-function \
  --function-name process-uploaded-document \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_deployment.zip \
  --role $LAMBDA_ROLE_ARN \
  --timeout 30 \
  --memory-size 256 \
  --vpc-config SubnetIds=$APP1,$APP2,SecurityGroupIds=$SG_LAMBDA \
  --environment "Variables={
    DB_HOST=$RDS_ENDPOINT,
    DB_PORT=3306,
    DB_NAME=insurance_docs,
    DB_USER=admin,
    DB_SECRET_ARN=$DB_SECRET_ARN,
    SECRET_ARN=$DB_SECRET_ARN
  }"
```

### Step 5.3 – Add S3 Trigger

```bash
BUCKET_NAME="insurance-docs-bucket-YOUR_ACCOUNT_ID"

# Allow S3 to invoke Lambda
aws lambda add-permission \
  --function-name process-uploaded-document \
  --statement-id s3-trigger \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$BUCKET_NAME

# Add S3 event notification
aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration "{
    \"LambdaFunctionConfigurations\": [{
      \"LambdaFunctionArn\": \"$(aws lambda get-function-configuration \
        --function-name process-uploaded-document \
        --query FunctionArn --output text)\",
      \"Events\": [\"s3:ObjectCreated:Put\"],
      \"Filter\": {\"Key\": {\"FilterRules\": [{\"Name\": \"prefix\", \"Value\": \"uploads/\"}]}}
    }]
  }"
```

---

## PART 6 – EC2 Application Deployment

### Step 6.1 – Create Launch Template

Use the User Data script from `infrastructure/ec2-userdata.sh`.

```bash
aws ec2 create-launch-template \
  --launch-template-name InsureDocs-LT \
  --version-description "v1" \
  --launch-template-data "{
    \"ImageId\": \"ami-0c02fb55956c7d316\",
    \"InstanceType\": \"t3.micro\",
    \"IamInstanceProfile\": {\"Name\": \"EC2InstanceProfile\"},
    \"SecurityGroupIds\": [\"$SG_EC2\"],
    \"UserData\": \"$(base64 -w 0 infrastructure/ec2-userdata.sh)\",
    \"TagSpecifications\": [{
      \"ResourceType\": \"instance\",
      \"Tags\": [{\"Key\": \"Name\", \"Value\": \"InsureDocs-EC2\"}]
    }]
  }"
```

### Step 6.2 – Create Target Group

```bash
TG_ARN=$(aws elbv2 create-target-group \
  --name InsureDocs-TG \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "Target Group: $TG_ARN"
```

### Step 6.3 – Create Application Load Balancer

```bash
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name InsureDocs-ALB \
  --subnets $PUB1 $PUB2 \
  --security-groups $SG_ALB \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Get DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' --output text)
echo "Application URL: http://$ALB_DNS"
```

### Step 6.4 – Create Auto Scaling Group

```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name InsureDocs-ASG \
  --launch-template LaunchTemplateName=InsureDocs-LT,Version='$Latest' \
  --min-size 1 --max-size 4 --desired-capacity 2 \
  --target-group-arns $TG_ARN \
  --vpc-zone-identifier "$APP1,$APP2" \
  --health-check-type ELB \
  --health-check-grace-period 120

# CPU-based scaling policy (scale out)
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name InsureDocs-ASG \
  --policy-name ScaleOut-CPU70 \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration \
    'TargetValue=70.0,PredefinedMetricSpecification={PredefinedMetricType=ASGAverageCPUUtilization}'
```

---

## PART 7 – Environment Variables

Set these in your EC2 Launch Template User Data (already done via `ec2-userdata.sh`):

```bash
export S3_BUCKET_NAME="insurance-docs-bucket-YOUR_ACCOUNT_ID"
export AWS_REGION="ap-south-1"
export PORT=80
```

---

## PART 8 – Verification

```bash
# 1. Access the portal
curl http://$ALB_DNS/health

# 2. Upload a test file
curl -X POST http://$ALB_DNS/upload \
  -F "document=@/path/to/test.pdf"

# 3. Check S3 for the uploaded file
aws s3 ls s3://$BUCKET_NAME/uploads/

# 4. Check Lambda logs
aws logs tail /aws/lambda/process-uploaded-document --follow

# 5. Verify DB entry
# Connect via Lambda test event or SSM Session Manager to check MySQL
```

---

## Local Development Setup

```bash
# 1. Clone the repo
git clone <repo-url>
cd cloud/webapp

# 2. Install dependencies
npm install

# 3. Set environment variables
export S3_BUCKET_NAME=your-bucket-name
export AWS_REGION=ap-south-1
export PORT=3000

# 4. Start the application
npm start

# Open http://localhost:3000 in your browser
```
