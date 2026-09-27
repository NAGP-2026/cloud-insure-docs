#!/bin/bash
# EC2 User Data Script – InsureDocs Portal
# Runs automatically when a new EC2 instance launches via ASG Launch Template.
# Application code is embedded inline – no separate artifact bucket needed.
# OS: Amazon Linux 2023

set -e
exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "======== InsureDocs EC2 Bootstrap Starting ========"

# ── 1. Update system packages ────────────────────────────────────────────────
dnf update -y

# ── 2. Install Node.js (AL2023 built-in – no external repo needed) ───────────
dnf install -y nodejs npm
echo "Node: $(node --version) | npm: $(npm --version)"

# ── 3. Get AWS metadata ──────────────────────────────────────────────────────
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
BUCKET_NAME="insurance-docs-bucket-742020474887"

# ── 4. Create app directory ──────────────────────────────────────────────────
mkdir -p /opt/insuredocs/public
cd /opt/insuredocs

# ── 5. Write package.json ────────────────────────────────────────────────────
cat > /opt/insuredocs/package.json << 'PKGJSON'
{
  "name": "insuredocs-portal",
  "version": "1.0.0",
  "main": "app.js",
  "scripts": { "start": "node app.js" },
  "dependencies": {
    "aws-sdk": "^2.1691.0",
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1"
  }
}
PKGJSON

# ── 6. Write app.js ──────────────────────────────────────────────────────────
cat > /opt/insuredocs/app.js << 'APPJS'
const express = require('express');
const multer  = require('multer');
const AWS     = require('aws-sdk');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 80;

const s3 = new AWS.S3({ region: process.env.AWS_REGION || 'ap-south-1' });
const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'insurance-docs-bucket';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.post('/upload', upload.single('document'), async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file provided.' });

  const file         = req.file;
  const timestamp    = Date.now();
  const safeName     = file.originalname.replace(/[^a-zA-Z0-9.\-_]/g, '_');
  const s3Key        = `uploads/${timestamp}-${safeName}`;

  const params = {
    Bucket: BUCKET_NAME,
    Key: s3Key,
    Body: file.buffer,
    ContentType: file.mimetype,
    ServerSideEncryption: 'AES256',
    Metadata: {
      'original-name':    file.originalname,
      'upload-timestamp': new Date().toISOString(),
      'content-type':     file.mimetype,
    },
  };

  try {
    const data = await s3.upload(params).promise();
    console.log(`[UPLOAD SUCCESS] ${data.Location}`);
    return res.status(200).json({
      success: true,
      message: 'File uploaded successfully!',
      fileName: file.originalname,
      s3Key,
      location: data.Location,
    });
  } catch (err) {
    console.error('[UPLOAD ERROR]', err);
    return res.status(500).json({ success: false, message: 'Upload failed.', error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`InsureDocs Portal running on port ${PORT}`);
  console.log(`S3 Bucket: ${BUCKET_NAME} | Region: ${process.env.AWS_REGION}`);
});
APPJS

# ── 7. Write public/index.html ───────────────────────────────────────────────
cat > /opt/insuredocs/public/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>InsureDocs – Self-Service Document Portal</title>
  <style>
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',sans-serif;background:#f0f4f8;min-height:100vh;display:flex;flex-direction:column;align-items:center}
    header{width:100%;background:#1a3c5e;color:#fff;padding:18px 40px;box-shadow:0 2px 8px rgba(0,0,0,.25)}
    header .logo{font-size:1.7rem;font-weight:700}
    header .tagline{font-size:.85rem;opacity:.75}
    main{width:100%;max-width:620px;margin:50px auto;padding:0 16px}
    .card{background:#fff;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,.1);padding:40px 44px}
    .card h2{color:#1a3c5e;margin-bottom:6px;font-size:1.4rem}
    .card p.subtitle{color:#6b7280;font-size:.92rem;margin-bottom:32px}
    .drop-zone{border:2px dashed #93c5fd;border-radius:10px;background:#eff6ff;padding:36px 20px;text-align:center;cursor:pointer;transition:background .2s,border-color .2s;position:relative}
    .drop-zone.dragover{background:#dbeafe;border-color:#3b82f6}
    .drop-zone input[type="file"]{position:absolute;inset:0;opacity:0;cursor:pointer;width:100%;height:100%}
    .drop-zone .icon{font-size:2.8rem;margin-bottom:10px}
    .drop-zone p{color:#374151;font-size:.95rem}
    .drop-zone .browse-link{color:#2563eb;text-decoration:underline;font-weight:600}
    .drop-zone .hint{font-size:.78rem;color:#9ca3af;margin-top:6px}
    #file-preview{display:none;margin-top:18px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:8px;padding:12px 16px;font-size:.88rem;word-break:break-all}
    #upload-btn{width:100%;margin-top:22px;padding:14px;background:#1a3c5e;color:#fff;border:none;border-radius:8px;font-size:1rem;font-weight:600;cursor:pointer;transition:background .2s;display:flex;align-items:center;justify-content:center;gap:8px}
    #upload-btn:hover:not(:disabled){background:#16325a}
    #upload-btn:disabled{background:#9ca3af;cursor:not-allowed}
    #progress-wrap{display:none;margin-top:18px;background:#e5e7eb;border-radius:99px;height:8px;overflow:hidden}
    #progress-bar{height:100%;background:#2563eb;width:0%;border-radius:99px;transition:width .3s ease}
    #status-msg{display:none;margin-top:18px;padding:14px 16px;border-radius:8px;font-size:.9rem;font-weight:500}
    #status-msg.success{background:#d1fae5;color:#065f46;border:1px solid #6ee7b7}
    #status-msg.error{background:#fee2e2;color:#991b1b;border:1px solid #fca5a5}
    .section-title{font-size:1rem;font-weight:600;color:#374151;margin:32px 0 12px}
    #upload-history{list-style:none;display:flex;flex-direction:column;gap:8px}
    #upload-history li{background:#f9fafb;border:1px solid #e5e7eb;border-radius:8px;padding:10px 14px;font-size:.85rem;display:flex;justify-content:space-between;align-items:center}
    #upload-history li .ts{color:#9ca3af;font-size:.78rem}
    .badge{background:#d1fae5;color:#065f46;border-radius:99px;padding:2px 10px;font-size:.75rem;font-weight:600}
    #no-uploads{color:#9ca3af;font-size:.88rem;text-align:center;padding:12px 0}
    footer{text-align:center;color:#9ca3af;font-size:.78rem;margin:10px 0 30px}
  </style>
</head>
<body>
<header>
  <div>
    <div class="logo">🛡️ InsureDocs</div>
    <div class="tagline">Secure Self-Service Document Portal</div>
  </div>
</header>
<main>
  <div class="card">
    <h2>Upload Your Document</h2>
    <p class="subtitle">Securely upload identity proofs, claim forms, or supporting evidence. Files are encrypted and stored on AWS S3.</p>
    <div class="drop-zone" id="drop-zone">
      <input type="file" id="file-input" accept="*/*"/>
      <div class="icon">📄</div>
      <p>Drag &amp; drop your file here, or <span class="browse-link">Browse</span></p>
      <p class="hint">Supports PDF, JPG, PNG, DOCX and more · Max 10 MB</p>
    </div>
    <div id="file-preview">📎 <span id="fname-label" style="font-weight:600;color:#1a3c5e"></span> <span id="fsize-label" style="color:#6b7280"></span></div>
    <button id="upload-btn" disabled><span>⬆️</span><span id="btn-text">Upload Document</span></button>
    <div id="progress-wrap"><div id="progress-bar"></div></div>
    <div id="status-msg"></div>
    <div class="section-title">Recent Uploads (this session)</div>
    <ul id="upload-history"><li id="no-uploads"><span>No uploads yet.</span></li></ul>
  </div>
</main>
<footer>© 2026 InsureDocs Portal &nbsp;|&nbsp; Hosted on AWS EC2 &nbsp;|&nbsp; All data encrypted in transit and at rest</footer>
<script>
  const dropZone=document.getElementById('drop-zone'),fileInput=document.getElementById('file-input'),
    filePreview=document.getElementById('file-preview'),fnameLabel=document.getElementById('fname-label'),
    fsizeLabel=document.getElementById('fsize-label'),uploadBtn=document.getElementById('upload-btn'),
    progressWrap=document.getElementById('progress-wrap'),progressBar=document.getElementById('progress-bar'),
    statusMsg=document.getElementById('status-msg'),uploadList=document.getElementById('upload-history'),
    noUploads=document.getElementById('no-uploads');
  let selectedFile=null;
  function formatSize(b){if(b<1024)return b+' B';if(b<1048576)return(b/1024).toFixed(1)+' KB';return(b/1048576).toFixed(2)+' MB';}
  function handleFileSelect(f){selectedFile=f;fnameLabel.textContent=f.name;fsizeLabel.textContent='('+formatSize(f.size)+')';filePreview.style.display='block';uploadBtn.disabled=false;hideStatus();}
  fileInput.addEventListener('change',()=>{if(fileInput.files.length>0)handleFileSelect(fileInput.files[0]);});
  dropZone.addEventListener('dragover',(e)=>{e.preventDefault();dropZone.classList.add('dragover');});
  dropZone.addEventListener('dragleave',()=>dropZone.classList.remove('dragover'));
  dropZone.addEventListener('drop',(e)=>{e.preventDefault();dropZone.classList.remove('dragover');if(e.dataTransfer.files.length>0)handleFileSelect(e.dataTransfer.files[0]);});
  uploadBtn.addEventListener('click',()=>{
    if(!selectedFile)return;
    const fd=new FormData();fd.append('document',selectedFile);
    uploadBtn.disabled=true;document.getElementById('btn-text').textContent='Uploading…';
    progressWrap.style.display='block';progressBar.style.width='0%';hideStatus();
    const xhr=new XMLHttpRequest();
    xhr.upload.addEventListener('progress',(e)=>{if(e.lengthComputable)progressBar.style.width=Math.round(e.loaded/e.total*100)+'%';});
    xhr.addEventListener('load',()=>{
      progressBar.style.width='100%';
      const res=JSON.parse(xhr.responseText);
      if(xhr.status===200&&res.success){showStatus('success','✅ "'+res.fileName+'" uploaded successfully to S3!');addHistory(res.fileName,res.s3Key);resetForm();}
      else{showStatus('error','❌ Upload failed: '+res.message);resetBtn();}
    });
    xhr.addEventListener('error',()=>{showStatus('error','❌ Network error. Try again.');resetBtn();});
    xhr.open('POST','/upload');xhr.send(fd);
  });
  function showStatus(t,m){statusMsg.className=t;statusMsg.textContent=m;statusMsg.style.display='block';}
  function hideStatus(){statusMsg.style.display='none';statusMsg.className='';}
  function resetBtn(){uploadBtn.disabled=false;document.getElementById('btn-text').textContent='Upload Document';progressWrap.style.display='none';}
  function resetForm(){resetBtn();selectedFile=null;fileInput.value='';filePreview.style.display='none';progressWrap.style.display='none';}
  function addHistory(name,key){if(noUploads)noUploads.remove();const li=document.createElement('li');const ts=new Date().toLocaleTimeString();li.innerHTML='<div><div style="font-weight:600;word-break:break-all">'+name+'</div><div class="ts">'+ts+' · '+key+'</div></div><span class="badge">Stored ✓</span>';uploadList.prepend(li);}
</script>
</body>
</html>
HTMLEOF

# ── 8. Set environment variables ──────────────────────────────────────────────
cat > /etc/profile.d/insuredocs.sh << EOF
export S3_BUCKET_NAME="${BUCKET_NAME}"
export AWS_REGION="${REGION}"
export PORT=80
export NODE_ENV=production
EOF

# ── 9. Install npm dependencies ───────────────────────────────────────────────
cd /opt/insuredocs
npm install --production

# ── 10. Create systemd service ────────────────────────────────────────────────
cat > /etc/systemd/system/insuredocs.service << 'SVCEOF'
[Unit]
Description=InsureDocs Document Upload Portal
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/insuredocs
Environment=S3_BUCKET_NAME=insurance-docs-bucket-742020474887
Environment=AWS_REGION=ap-south-1
Environment=PORT=80
Environment=NODE_ENV=production
ExecStart=/usr/bin/node /opt/insuredocs/app.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=insuredocs

[Install]
WantedBy=multi-user.target
SVCEOF

# ── 12. Enable and start service ──────────────────────────────────────────────
systemctl daemon-reload
systemctl enable insuredocs
systemctl start insuredocs

echo "======== InsureDocs EC2 Bootstrap Complete ========"
systemctl status insuredocs --no-pager
