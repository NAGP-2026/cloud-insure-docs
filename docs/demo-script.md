# 🎬 Demo Script — Running Application (2 Minutes)
## InsureDocs Self-Service Portal — NAGP Cloud Computing Case Study

> **Instructions:** Read each line naturally while doing the action. Keep a steady pace.

---

### [0:00 – 0:15] Open the Application

**ACTION:** Open browser → paste the ALB URL

**SAY:**
> "This is the InsureDocs Self-Service Document Upload Portal, hosted on AWS.
> The application is running on EC2 instances behind an Application Load Balancer.
> I am accessing it using the ALB's public DNS name over HTTP."

---

### [0:15 – 0:40] Upload a File

**ACTION:** Click "Browse" → select a PDF file → click "Upload Document"

**SAY:**
> "I will now upload a document — this simulates a customer uploading an identity proof or claim form.
> I'll click Browse, select a PDF file from my machine, and click Upload.
> The file is being uploaded directly to Amazon S3 from the EC2 backend."

**ACTION:** Wait for success message to appear

**SAY:**
> "The upload is successful. You can see the confirmation message — the file has been stored in S3."

---

### [0:40 – 1:05] Verify File in S3

**ACTION:** Switch to AWS Console → S3 → insurance-docs-bucket-742020474887 → uploads/ folder

**SAY:**
> "Now let me verify the file is actually stored in Amazon S3.
> I'll navigate to the S3 bucket — insurance-docs-bucket — and open the uploads folder.
> Here we can see the uploaded file with a timestamp prefix in its name.
> S3 versioning is enabled, and the bucket is fully private — no public access."

---

### [1:05 – 1:35] Show Lambda Execution & DB Record

**ACTION:** Switch to CloudWatch → Log groups → /aws/lambda/process-uploaded-document → latest log stream

**SAY:**
> "The file upload also triggered an AWS Lambda function automatically via an S3 event notification.
> Let me open the CloudWatch logs for the Lambda function.
> Here you can see the Lambda was invoked immediately after the upload."

**ACTION:** Scroll to show these log lines:
- `[FILE] name=... content_type=application/pdf`
- `[DB INSERT] SUCCESS id=1 ...`

**SAY:**
> "The Lambda extracted the file name and content type — application/pdf.
> It then connected to our RDS MySQL database and inserted a record.
> You can see the DB INSERT SUCCESS log — record ID 1 was created with the file name, content type, and upload timestamp."

---

### [1:35 – 1:55] Show CloudWatch Dashboard

**ACTION:** Navigate to CloudWatch → Dashboards → InsureDocs-Dashboard

**SAY:**
> "Finally, let me show the CloudWatch Dashboard called InsureDocs-Dashboard.
> It shows EC2 CPU utilization from our Auto Scaling Group, ALB request count across both Availability Zones, Lambda invocations, and Lambda errors — all in one place.
> This gives us full observability of the system."

---

### [1:55 – 2:00] Close

**SAY:**
> "That completes the application demo — file upload, S3 storage, Lambda processing, RDS database entry, and CloudWatch monitoring — all working end to end. Thank you."

---

> ✅ Total time: ~2 minutes
