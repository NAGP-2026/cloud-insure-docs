# Scope and Assumptions
## InsureDocs Self-Service Document Portal – NAGP Cloud Computing Case Study

---

## Scope

This document covers the first MVP release of the InsureDocs customer-facing document upload portal, deployed on AWS using cloud-native services.

### In Scope
- Single AWS Region deployment (ap-south-1)
- VPC with 6 subnets across 2 Availability Zones
- EC2-based web application behind an Application Load Balancer
- Auto Scaling Group for compute elasticity
- S3 for durable document storage
- Lambda for event-driven metadata processing
- RDS MySQL for structured metadata storage
- IAM roles following the Principle of Least Privilege
- AWS Secrets Manager for credential management
- CloudWatch for logging and monitoring (bonus: dashboards & alarms)

### Out of Scope (MVP)
- User authentication and authorization (Cognito / OAuth)
- Document scanning / antivirus processing
- HTTPS/TLS termination at ALB (requires ACM certificate and domain name)
- Multi-region deployment or disaster recovery
- CI/CD pipeline (CodePipeline / CodeDeploy)
- Advanced UI/UX design
- SLA or performance SLOs beyond Free Tier constraints

---

## Assumptions

### Infrastructure

1. **Single AWS Account:** A new Free Tier eligible AWS account is used for this assignment. All resources are within this single account.

2. **Single Region:** All resources are deployed in `ap-south-1` (Mumbai) for simplicity and Free Tier availability.

3. **Free Tier Constraints:**
   - EC2 instances use `t3.micro` (750 hrs/month free)
   - RDS uses `db.t3.micro` (750 hrs/month free, single-AZ in practice; Multi-AZ described architecturally)
   - Lambda: 1M free requests/month and 400,000 GB-seconds compute — well within budget for demo

4. **NAT Gateway Not Deployed:** NAT Gateway costs ~$32/month minimum and is not Free Tier eligible. Per assignment guidance, NAT Gateway is depicted in the architecture diagram but not provisioned. Private subnets use the Internet Gateway for outbound internet access during development.

5. **HTTP Only:** The portal is accessible via HTTP (port 80) as HTTPS requires a registered domain and ACM certificate. In a production scenario, HTTPS with a valid TLS certificate would be mandatory.

6. **No SSH Access in Production:** EC2 instances are managed via AWS Systems Manager Session Manager. Port 22 is not opened in Security Groups.

### Application

7. **File Size Limit:** Maximum file upload size is 10 MB. This is suitable for typical insurance documents (PDFs, images, DOCX files). Large video files are out of scope.

8. **No File Type Validation (Server-side):** The MVP accepts any file type. A production system should validate MIME types and run malware scanning.

9. **No Authentication:** The portal is open to any internet user in the MVP. Authentication (e.g., AWS Cognito) is planned for the next release.

10. **EC2 Runtime:** Node.js 18 LTS on Amazon Linux 2023 is used. The application is started via a `systemd` service for auto-restart on instance reboot.

### Database

11. **Database Engine:** MySQL 8.0 on Amazon RDS is selected because:
    - Well-supported in the Free Tier (`db.t3.micro`)
    - Familiar SQL interface
    - Good pymysql library support for Lambda

12. **Single-AZ RDS (Actual):** While the architecture diagram shows Multi-AZ for high availability design, the actual deployment uses a Single-AZ RDS instance to stay within Free Tier limits. Multi-AZ is described as the target production configuration.

13. **RDS Access:** Only the Lambda function can connect to RDS (enforced via Security Group). EC2 instances do not have direct database access.

### Lambda

14. **Cold Start Latency:** Lambda cold starts may add 1–3 seconds of latency for the first invocation after idle periods. This is acceptable for background metadata processing (not on the critical user path).

15. **Lambda VPC Configuration:** Lambda runs inside the VPC to access RDS in private subnets. This adds ~10ms latency but is required for network isolation.

16. **pymysql Layer:** The `pymysql` library is packaged as a Lambda Layer or included in the deployment ZIP since it is not part of the standard Python Lambda runtime.

### Security

17. **Secrets Manager Costs:** AWS Secrets Manager has a small cost (~$0.40/secret/month + API call costs). For this assignment, two secrets are created (DB password + bonus demo secret).

18. **KMS:** Default AWS-managed KMS keys are used for RDS and S3 encryption. Customer-managed KMS keys are not configured due to Free Tier scope.

19. **IAM Users:** IAM users are created for the development team with programmatic access only (no Console access unless required). MFA is recommended but not enforced in the demo account.

---

## Limitations

| Limitation | Impact | Mitigation |
|---|---|---|
| No HTTPS | Data in transit between browser and ALB is unencrypted | Acceptable for demo; add ACM cert + domain for production |
| NAT Gateway not deployed | Private subnet instances need IGW for outbound traffic | Described architecturally; route through IGW for demo |
| Single-AZ RDS | Single point of failure at DB tier | Enable Multi-AZ for production |
| No authentication | Anyone with the URL can upload files | Add Cognito/OAuth in next release |
| File type not validated | Malicious files could be uploaded | Add Lambda trigger for antivirus scan |
| t3.micro performance | Limited CPU/RAM under heavy load | ASG will scale out but each instance is limited |

---

## Clean-Up Checklist

After demo and recording, delete resources in this order to avoid charges:

1. [ ] Delete Auto Scaling Group
2. [ ] Delete Application Load Balancer and Target Group
3. [ ] Terminate EC2 instances
4. [ ] Delete Launch Template
5. [ ] Delete RDS instance (skip final snapshot to avoid storage charges)
6. [ ] Delete RDS Subnet Group
7. [ ] Empty and delete S3 bucket
8. [ ] Delete Lambda function and associated IAM role
9. [ ] Delete Secrets Manager secrets
10. [ ] Delete CloudWatch Log Groups
11. [ ] Delete VPC (will also delete subnets, route tables, IGW, security groups, NACLs)
12. [ ] Delete IAM users, groups, and policies created for the dev team
13. [ ] Verify billing dashboard shows $0.00 in upcoming charges
