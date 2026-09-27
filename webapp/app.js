/**
 * Insurance Document Upload Portal
 * EC2-hosted Node.js/Express web application
 * Handles file uploads and stores them in AWS S3
 */

const express = require('express');
const multer = require('multer');
const AWS = require('aws-sdk');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 80;

// ─── AWS Configuration ────────────────────────────────────────────────────────
// Credentials are sourced from the EC2 Instance Profile (IAM Role),
// so no hard-coded keys are needed here.
const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'ap-south-1',
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'insurance-docs-bucket';

// ─── Multer – in-memory storage (file is streamed directly to S3) ─────────────
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB limit
});

// ─── Serve static files ───────────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public')));

// ─── Health-check endpoint (used by ALB target group) ────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// ─── File Upload Endpoint ─────────────────────────────────────────────────────
app.post('/upload', upload.single('document'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No file provided.' });
  }

  const file = req.file;
  const timestamp = Date.now();
  const safeOriginalName = file.originalname.replace(/[^a-zA-Z0-9.\-_]/g, '_');
  const s3Key = `uploads/${timestamp}-${safeOriginalName}`;

  const params = {
    Bucket: BUCKET_NAME,
    Key: s3Key,
    Body: file.buffer,
    ContentType: file.mimetype,
    // Server-side encryption using AWS managed keys
    ServerSideEncryption: 'AES256',
    Metadata: {
      'original-name': file.originalname,
      'upload-timestamp': new Date().toISOString(),
      'content-type': file.mimetype,
    },
  };

  try {
    const data = await s3.upload(params).promise();
    console.log(`[UPLOAD SUCCESS] File stored at: ${data.Location}`);
    return res.status(200).json({
      success: true,
      message: 'File uploaded successfully!',
      fileName: file.originalname,
      s3Key,
      location: data.Location,
    });
  } catch (err) {
    console.error('[UPLOAD ERROR]', err);
    return res.status(500).json({
      success: false,
      message: 'Upload failed. Please try again.',
      error: err.message,
    });
  }
});

// ─── Start Server ─────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Insurance Portal running on port ${PORT}`);
  console.log(`S3 Bucket: ${BUCKET_NAME}`);
  console.log(`Region   : ${process.env.AWS_REGION || 'ap-south-1'}`);
});
