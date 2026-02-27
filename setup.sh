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
<title>AzureSphere | Server Connectivity Dashboard</title>

<style>
*{margin:0;padding:0;box-sizing:border-box}

body{
    font-family: Arial, Helvetica, sans-serif;
    background: linear-gradient(135deg,#0b1721 0%,#1a2f3f 100%);
    color:#e5e9f0;
    min-height:100vh;
    overflow-x:hidden;
}

body::before{
    content:'';
    position:fixed;
    width:100%;
    height:100%;
    background-image:
        radial-gradient(circle at 20% 30%,rgba(0,255,255,.05)0%,transparent 20%),
        radial-gradient(circle at 80% 70%,rgba(0,200,255,.05)0%,transparent 20%);
    pointer-events:none;
}

.container{max-width:1400px;margin:0 auto;padding:30px 24px}

/* HEADER */
.header{display:flex;justify-content:space-between;align-items:center;margin-bottom:30px;flex-wrap:wrap;gap:20px}
.header-left{display:flex;align-items:center;gap:15px}

.logo-icon{
    width:50px;height:50px;
    background:linear-gradient(135deg,#00d2ff 0%,#3a7bd5 100%);
    border-radius:16px;
    display:flex;align-items:center;justify-content:center;
    font-size:22px;color:#fff
}

.header-title h1{
    font-size:26px;font-weight:600;
    background:linear-gradient(135deg,#fff 0%,#b0e0ff 100%);
    -webkit-background-clip:text;
    -webkit-text-fill-color:transparent;
}

.subtitle{color:#8a9db0;font-size:14px;margin-top:5px}

.header-right{display:flex;gap:15px;align-items:center}

.status-badge,.time-display{
    background:rgba(255,255,255,.08);
    padding:10px 18px;
    border-radius:40px;
    font-size:14px
}

.stats-overview{
    display:grid;
    grid-template-columns:repeat(auto-fit,minmax(250px,1fr));
    gap:20px;margin-bottom:30px
}

.stat-card{
    background:rgba(255,255,255,.05);
    border-radius:24px;
    padding:20px;
    display:flex;align-items:center;gap:20px
}

.stat-icon{
    width:55px;height:55px;
    background:rgba(0,210,255,.15);
    border-radius:18px;
    display:flex;align-items:center;justify-content:center;
    font-size:24px;color:#00d2ff
}

.stat-value{font-size:26px;font-weight:600}

.dashboard-grid{
    display:grid;
    grid-template-columns:repeat(2,1fr);
    gap:25px
}

.grid-card{
    background:rgba(20,30,40,.6);
    border-radius:28px;
    padding:25px
}

.card-header{display:flex;align-items:center;gap:12px;margin-bottom:20px;font-size:18px}

.metric-row{
    display:flex;
    justify-content:space-between;
    padding:10px 0;
    border-bottom:1px solid rgba(255,255,255,.05)
}

.health-bar{
    height:8px;background:rgba(255,255,255,.1);
    border-radius:10px;margin:15px 0;overflow:hidden
}

.health-fill{
    height:100%;
    background:linear-gradient(90deg,#00d2ff,#3a7bd5)
}

.footer{
    margin-top:50px;
    padding-top:20px;
    border-top:1px solid rgba(255,255,255,.05);
    font-size:14px;color:#8a9db0
}

@media(max-width:900px){
.dashboard-grid{grid-template-columns:1fr}
}
</style>
</head>

<body>
<div class="container">

<div class="header">
<div class="header-left">
<div class="logo-icon">☁</div>
<div class="header-title">
<h1>AzureSphere Dashboard</h1>
<div class="subtitle">● Azure VM • Server Monitoring • Live</div>
</div>
</div>

<div class="header-right">
<div class="status-badge">🛡 All Systems Operational</div>
<div class="time-display" id="liveTime">--</div>
</div>
</div>

<div class="stats-overview">

<div class="stat-card">
<div class="stat-icon">🖥</div>
<div>
<div>Server Uptime</div>
<div class="stat-value" id="uptime">--</div>
</div>
</div>

<div class="stat-card">
<div class="stat-icon">🌐</div>
<div>
<div>Active Connections</div>
<div class="stat-value" id="totalConnections">--</div>
</div>
</div>

<div class="stat-card">
<div class="stat-icon">💾</div>
<div>
<div>Data Transferred</div>
<div class="stat-value">2.4 GB</div>
</div>
</div>

</div>

<div class="dashboard-grid">

<div class="grid-card">
<div class="card-header">🔒 HTTPS Security Status</div>
<div class="metric-row"><span>Port</span><span>443 Active</span></div>
<div class="metric-row"><span>Server IP</span><span>Your IP</span></div>
<div class="metric-row"><span>SSL</span><span>Valid</span></div>
<div class="health-bar"><div class="health-fill" style="width:100%"></div></div>
</div>

<div class="grid-card">
<div class="card-header">📊 HTTP Traffic</div>
<div class="metric-row"><span>Total Requests</span><span id="requests">--</span></div>
<div class="metric-row"><span>Active Connections</span><span id="connections">--</span></div>
</div>

<div class="grid-card">
<div class="card-header">📁 SFTP Service</div>
<div class="metric-row"><span>Port</span><span>2222 Active</span></div>
<div class="metric-row"><span>User</span><span>testuser</span></div>
<div class="metric-row"><span>Directory</span><span>/home/testuser</span></div>
</div>

<div class="grid-card">
<div class="card-header">🌤 Brisbane Weather (Static)</div>
<div class="metric-row"><span>Temperature</span><span>27°C</span></div>
<div class="metric-row"><span>Humidity</span><span>65%</span></div>
<div class="metric-row"><span>Wind</span><span>12 km/h</span></div>
</div>

</div>

<div class="footer">
© 2026 AzureSphere Connectivity Lab • Docker + Nginx + SFTP
</div>

</div>

<script>
function updateDashboard(){
    // Check if all elements exist before updating
    let requestsElement = document.getElementById("requests");
    let connectionsElement = document.getElementById("connections");
    let totalConnectionsElement = document.getElementById("totalConnections");
    let uptimeElement = document.getElementById("uptime");
    
    let requests=Math.floor(Math.random()*8500)+1500;
    let connections=Math.floor(Math.random()*350)+50;
    
    if (requestsElement) {
        requestsElement.innerText=requests.toLocaleString();
    }
    
    if (connectionsElement) {
        connectionsElement.innerText=connections.toLocaleString();
    }
    
    if (totalConnectionsElement) {
        totalConnectionsElement.innerText=connections.toLocaleString();
    }

    let d=Math.floor(Math.random()*30)+15;
    let h=Math.floor(Math.random()*24);
    
    if (uptimeElement) {
        uptimeElement.innerText=d+"d "+h+"h";
    }
}

function updateClock(){
    let now=new Date();
    let timeElement = document.getElementById("liveTime");
    
    // Format the date to show consistently
    let options = { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric', 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        hour12: true 
    };
    
    if (timeElement) {
        timeElement.innerText=now.toLocaleString('en-US', options);
    }
}

// Wait for DOM to be fully loaded before initial updates
document.addEventListener('DOMContentLoaded', function() {
    updateDashboard();
    updateClock();
    
    // Set up intervals
    setInterval(updateDashboard, 10000);
    setInterval(updateClock, 1000);
});
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
