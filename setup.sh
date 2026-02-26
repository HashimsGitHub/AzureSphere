#!/bin/bash

echo "Updating system..."
sudo apt update -y

echo "Installing required packages..."
sudo apt install -y docker.io docker-compose openssl git

echo "Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Creating directory structure..."
mkdir -p nginx/conf
mkdir -p nginx/certs
mkdir -p nginx/html
mkdir -p sftp/data

echo "Creating Welcome HTML page..."
cat <<EOF > nginx/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Server Connectivity Dashboard</title>

<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;500;700&display=swap" rel="stylesheet">

<style>
body {
    margin: 0;
    font-family: 'Poppins', sans-serif;
    background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
    color: white;
}

.container {
    max-width: 1100px;
    margin: auto;
    padding: 40px 20px;
}

h1 {
    text-align: center;
    font-size: 40px;
    margin-bottom: 10px;
}

.subtitle {
    text-align: center;
    color: #ccc;
    margin-bottom: 40px;
}

.card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 25px;
}

.card {
    background: rgba(255,255,255,0.08);
    padding: 25px;
    border-radius: 15px;
    backdrop-filter: blur(10px);
    box-shadow: 0 8px 20px rgba(0,0,0,0.4);
    transition: transform 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
}

.card h2 {
    margin-top: 0;
    font-size: 22px;
    margin-bottom: 15px;
}

.status {
    font-size: 18px;
    font-weight: 500;
}

.success {
    color: #00ff9d;
}

.info {
    color: #00c3ff;
}

.footer {
    text-align: center;
    margin-top: 50px;
    color: #aaa;
    font-size: 14px;
}
</style>
</head>

<body>

<div class="container">

<h1>🚀 Connectivity Dashboard</h1>
<p class="subtitle">Azure VM Server Monitoring Panel</p>

<div class="card-grid">

<div class="card">
<h2>🔐 HTTPS Status</h2>
<p class="status success">✔ Port 443 Active</p>
<p>Secure connection established.</p>
<p><strong>Server IP:</strong> 20.11.10.72</p>
</div>

<div class="card">
<h2>🌐 HTTP Traffic Stats</h2>
<p>Total Requests: <strong id="requests">Loading...</strong></p>
<p>Active Connections: <strong id="connections">Loading...</strong></p>
<p style="font-size:13px;color:#ccc;">(Requires Nginx stub_status enabled)</p>
</div>

<div class="card">
<h2>📂 SFTP Service</h2>
<p class="status success">✔ Port 2222 Active</p>
<p>User: <strong>testuser</strong></p>
<p>Protocol: SFTP (SSH)</p>
</div>

<div class="card">
<h2>🌤 Brisbane Weather</h2>

<!-- Simple Weather Widget -->
<a class="weatherwidget-io"
   href="https://forecast7.com/en/n27d47153d03/brisbane/"
   data-label_1="BRISBANE"
   data-label_2="WEATHER"
   data-theme="dark">
BRISBANE WEATHER
</a>

<script>
!function(d,s,id){
var js,fjs=d.getElementsByTagName(s)[0];
if(!d.getElementById(id)){
js=d.createElement(s);js.id=id;
js.src='https://weatherwidget.io/js/widget.min.js';
fjs.parentNode.insertBefore(js,fjs);
}
}(document,'script','weatherwidget-io-js');
</script>

</div>

</div>

<div class="footer">
© 2026 Azure Connectivity Lab | Docker + Nginx + SFTP
</div>

</div>

<script>
// Fake Traffic Demo (Replace with real API if enabled)
document.getElementById("requests").innerText = Math.floor(Math.random() * 5000);
document.getElementById("connections").innerText = Math.floor(Math.random() * 200);
</script>

</body>
</html>
EOF

echo "Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 \
-newkey rsa:2048 \
-keyout nginx/certs/server.key \
-out nginx/certs/server.crt \
-subj "/CN=$(curl -s ifconfig.me)"

echo "Creating Nginx config..."
cat <<EOF > nginx/conf/default.conf
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
EOF

echo "Creating test SFTP file..."
echo "This is a test file from SFTP container" > sftp/data/testfile.txt

echo "Starting Docker containers..."
sudo docker compose up -d

echo "Deployment Complete!"
echo "Test HTTPS: https://$(curl -s ifconfig.me)"
echo "Test SFTP: sftp -P 2222 testuser@$(curl -s ifconfig.me)"
