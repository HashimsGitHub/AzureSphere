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
    
    <!-- Fonts & Icons -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, #0b1721 0%, #1a2f3f 100%);
            color: #e5e9f0;
            min-height: 100vh;
            position: relative;
            overflow-x: hidden;
        }

        /* Animated background particles */
        body::before {
            content: '';
            position: fixed;
            width: 100%;
            height: 100%;
            background-image: 
                radial-gradient(circle at 20% 30%, rgba(0, 255, 255, 0.05) 0%, transparent 20%),
                radial-gradient(circle at 80% 70%, rgba(0, 200, 255, 0.05) 0%, transparent 20%);
            pointer-events: none;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px 24px;
            position: relative;
            z-index: 1;
        }

        /* Header Section */
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
            flex-wrap: wrap;
            gap: 20px;
        }

        .header-left {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .logo-icon {
            width: 50px;
            height: 50px;
            background: linear-gradient(135deg, #00d2ff 0%, #3a7bd5 100%);
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            color: white;
            box-shadow: 0 10px 20px rgba(0, 210, 255, 0.3);
        }

        .header-title h1 {
            font-size: 28px;
            font-weight: 600;
            background: linear-gradient(135deg, #fff 0%, #b0e0ff 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 5px;
        }

        .header-title .subtitle {
            color: #8a9db0;
            font-size: 14px;
            font-weight: 400;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .header-title .subtitle i {
            font-size: 12px;
            color: #4cd964;
        }

        .header-right {
            display: flex;
            gap: 15px;
            align-items: center;
        }

        .status-badge {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 10px 20px;
            border-radius: 40px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 14px;
        }

        .status-badge i {
            color: #4cd964;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }

        .time-display {
            background: rgba(0, 0, 0, 0.3);
            padding: 10px 20px;
            border-radius: 40px;
            font-size: 14px;
            font-weight: 500;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        /* Stats Overview */
        .stats-overview {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-card {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 24px;
            padding: 20px;
            display: flex;
            align-items: center;
            gap: 20px;
            transition: all 0.3s ease;
        }

        .stat-card:hover {
            background: rgba(255, 255, 255, 0.08);
            transform: translateY(-2px);
            border-color: rgba(0, 210, 255, 0.3);
        }

        .stat-icon {
            width: 55px;
            height: 55px;
            background: linear-gradient(135deg, #00d2ff20 0%, #3a7bd520 100%);
            border-radius: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            color: #00d2ff;
        }

        .stat-content h3 {
            font-size: 14px;
            font-weight: 400;
            color: #8a9db0;
            margin-bottom: 5px;
        }

        .stat-content .stat-value {
            font-size: 28px;
            font-weight: 600;
            color: white;
            line-height: 1.2;
        }

        .stat-content .stat-label {
            font-size: 12px;
            color: #4cd964;
            margin-top: 5px;
        }

        /* Main Dashboard Grid */
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 25px;
            margin-bottom: 30px;
        }

        .grid-card {
            background: rgba(20, 30, 40, 0.6);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 28px;
            padding: 25px;
            transition: all 0.3s ease;
        }

        .grid-card:hover {
            border-color: rgba(0, 210, 255, 0.2);
            box-shadow: 0 20px 30px -10px rgba(0, 0, 0, 0.5);
        }

        .card-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 20px;
        }

        .card-header i {
            font-size: 24px;
            color: #00d2ff;
            background: rgba(0, 210, 255, 0.1);
            padding: 10px;
            border-radius: 14px;
        }

        .card-header h2 {
            font-size: 18px;
            font-weight: 500;
            color: white;
        }

        .card-content {
            color: #cbd5e0;
        }

        /* Status Indicators */
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 15px;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 16px;
            margin-bottom: 15px;
        }

        .status-badge.success {
            background: rgba(76, 217, 100, 0.15);
            color: #4cd964;
            padding: 6px 12px;
            border-radius: 40px;
            font-size: 13px;
            font-weight: 500;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .status-badge.info {
            background: rgba(0, 210, 255, 0.15);
            color: #00d2ff;
        }

        .metric-row {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .metric-label {
            color: #8a9db0;
            font-size: 14px;
        }

        .metric-value {
            font-weight: 600;
            color: white;
        }

        .metric-value.highlight {
            color: #00d2ff;
        }

        /* Weather Widget Customization */
        .weather-container {
            background: linear-gradient(135deg, rgba(0, 100, 150, 0.2), rgba(0, 50, 100, 0.2));
            border-radius: 20px;
            padding: 15px;
        }

        .weatherwidget-io {
            border-radius: 16px !important;
            overflow: hidden;
        }

        /* System Health */
        .health-bar {
            height: 8px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            margin: 15px 0;
            overflow: hidden;
        }

        .health-fill {
            height: 100%;
            width: 85%;
            background: linear-gradient(90deg, #00d2ff, #3a7bd5);
            border-radius: 10px;
            animation: glow 2s ease-in-out infinite alternate;
        }

        @keyframes glow {
            from { opacity: 0.8; }
            to { opacity: 1; }
        }

        /* Activity List */
        .activity-list {
            margin-top: 20px;
        }

        .activity-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .activity-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #4cd964;
        }

        .activity-dot.warning {
            background: #ffd534;
        }

        /* Footer */
        .footer {
            margin-top: 50px;
            padding-top: 30px;
            border-top: 1px solid rgba(255, 255, 255, 0.05);
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: #8a9db0;
            font-size: 14px;
            flex-wrap: wrap;
            gap: 20px;
        }

        .footer-links {
            display: flex;
            gap: 25px;
        }

        .footer-links a {
            color: #8a9db0;
            text-decoration: none;
            transition: color 0.3s;
        }

        .footer-links a:hover {
            color: #00d2ff;
        }

        /* Responsive Design */
        @media (max-width: 900px) {
            .dashboard-grid {
                grid-template-columns: 1fr;
            }
            
            .header {
                flex-direction: column;
                align-items: flex-start;
            }
            
            .header-right {
                width: 100%;
                justify-content: space-between;
            }
        }

        @media (max-width: 600px) {
            .stats-overview {
                grid-template-columns: 1fr;
            }
            
            .header-right {
                flex-direction: column;
                align-items: stretch;
            }
            
            .time-display, .status-badge {
                text-align: center;
            }
        }
    </style>
</head>
<body>

<div class="container">
    <!-- Header -->
    <div class="header">
        <div class="header-left">
            <div class="logo-icon">
                <i class="fas fa-cloud"></i>
            </div>
            <div class="header-title">
                <h1>AzureSphere Dashboard</h1>
                <div class="subtitle">
                    <i class="fas fa-circle"></i>
                    Azure VM • Server Monitoring • Live
                </div>
            </div>
        </div>
        
        <div class="header-right">
            <div class="status-badge">
                <i class="fas fa-shield-alt"></i>
                <span>All Systems Operational</span>
            </div>
            <div class="time-display" id="liveTime">
                <i class="far fa-clock"></i>
                <span></span>
            </div>
        </div>
    </div>

    <!-- Stats Overview -->
    <div class="stats-overview">
        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-server"></i>
            </div>
            <div class="stat-content">
                <h3>Server Uptime</h3>
                <div class="stat-value" id="uptime">24d 13h</div>
                <div class="stat-label">98.9% Availability</div>
            </div>
        </div>
        
        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-network-wired"></i>
            </div>
            <div class="stat-content">
                <h3>Active Connections</h3>
                <div class="stat-value" id="totalConnections">157</div>
                <div class="stat-label">↑ 12% from yesterday</div>
            </div>
        </div>
        
        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-database"></i>
            </div>
            <div class="stat-content">
                <h3>Data Transferred</h3>
                <div class="stat-value">2.4 GB</div>
                <div class="stat-label">Last 24 hours</div>
            </div>
        </div>
    </div>

    <!-- Main Dashboard Grid -->
    <div class="dashboard-grid">
        <!-- HTTPS Status Card -->
        <div class="grid-card">
            <div class="card-header">
                <i class="fas fa-lock"></i>
                <h2>HTTPS Security Status</h2>
            </div>
            <div class="card-content">
                <div class="status-indicator">
                    <span class="status-badge success">
                        <i class="fas fa-check-circle"></i> Port 443 Active
                    </span>
                    <span style="margin-left: auto; font-size: 13px;">SSL/TLS 1.3</span>
                </div>
                
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-globe"></i> Server IP</span>
                    <span class="metric-value highlight">20.11.10.72</span>
                </div>
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-certificate"></i> SSL Certificate</span>
                    <span class="metric-value">Valid (90 days)</span>
                </div>
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-shield-virus"></i> Security Rating</span>
                    <span class="metric-value" style="color: #4cd964;">A+</span>
                </div>
                
                <div class="health-bar">
                    <div class="health-fill" style="width: 100%;"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 12px; color: #8a9db0;">
                    <span>Security Score</span>
                    <span>Excellent</span>
                </div>
            </div>
        </div>

        <!-- HTTP Traffic Card -->
        <div class="grid-card">
            <div class="card-header">
                <i class="fas fa-chart-line"></i>
                <h2>HTTP Traffic Analytics</h2>
            </div>
            <div class="card-content">
                <div style="display: flex; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; text-align: center; padding: 15px; background: rgba(0,0,0,0.2); border-radius: 16px;">
                        <div style="font-size: 28px; font-weight: 700; color: #00d2ff;" id="requests">--</div>
                        <div style="font-size: 12px; color: #8a9db0;">Total Requests</div>
                    </div>
                    <div style="flex: 1; text-align: center; padding: 15px; background: rgba(0,0,0,0.2); border-radius: 16px;">
                        <div style="font-size: 28px; font-weight: 700; color: #4cd964;" id="connections">--</div>
                        <div style="font-size: 12px; color: #8a9db0;">Active Connections</div>
                    </div>
                </div>
                
                <div class="metric-row">
                    <span class="metric-label">Requests/min</span>
                    <span class="metric-value" id="requestsPerMin">342</span>
                </div>
                <div class="metric-row">
                    <span class="metric-label">Bandwidth Usage</span>
                    <span class="metric-value">45 Mbps</span>
                </div>
                
                <div class="activity-list">
                    <div class="activity-item">
                        <span class="activity-dot"></span>
                        <span style="flex: 1;">GET /api/status</span>
                        <span style="color: #8a9db0;">2s ago</span>
                    </div>
                    <div class="activity-item">
                        <span class="activity-dot warning"></span>
                        <span style="flex: 1;">POST /auth/login</span>
                        <span style="color: #8a9db0;">5s ago</span>
                    </div>
                </div>
                
                <p style="font-size: 12px; color: #8a9db0; margin-top: 15px;">
                    <i class="fas fa-info-circle"></i> Nginx stub_status enabled
                </p>
            </div>
        </div>

        <!-- SFTP Service Card -->
        <div class="grid-card">
            <div class="card-header">
                <i class="fas fa-folder"></i>
                <h2>SFTP File Transfer</h2>
            </div>
            <div class="card-content">
                <div class="status-indicator">
                    <span class="status-badge success">
                        <i class="fas fa-check-circle"></i> Port 2222 Active
                    </span>
                </div>
                
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-user"></i> Username</span>
                    <span class="metric-value">testuser</span>
                </div>
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-folder-open"></i> Home Directory</span>
                    <span class="metric-value">/home/testuser</span>
                </div>
                <div class="metric-row">
                    <span class="metric-label"><i class="fas fa-key"></i> Auth Method</span>
                    <span class="metric-value">Password & Key</span>
                </div>
                
                <div style="margin-top: 20px; padding: 15px; background: rgba(0,0,0,0.2); border-radius: 16px;">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
                        <span>Disk Usage</span>
                        <span>2.4 GB / 20 GB</span>
                    </div>
                    <div class="health-bar">
                        <div class="health-fill" style="width: 12%;"></div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Weather Card -->
        <div class="grid-card">
            <div class="card-header">
                <i class="fas fa-cloud-sun"></i>
                <h2>Brisbane Weather</h2>
            </div>
            <div class="card-content">
                <div class="weather-container">
                    <a class="weatherwidget-io"
                       href="https://forecast7.com/en/n27d47153d03/brisbane/"
                       data-label_1="BRISBANE"
                       data-label_2="WEATHER"
                       data-theme="dark"
                       data-basecolor="#1a2f3f"
                       data-accent="#00d2ff">
                    BRISBANE WEATHER
                    </a>
                </div>
                
                <div style="margin-top: 20px; display: flex; gap: 15px; justify-content: center;">
                    <div style="text-align: center;">
                        <i class="fas fa-wind"></i>
                        <div style="font-size: 12px;">Wind</div>
                        <div style="font-weight: 600;">12 km/h</div>
                    </div>
                    <div style="text-align: center;">
                        <i class="fas fa-tint"></i>
                        <div style="font-size: 12px;">Humidity</div>
                        <div style="font-weight: 600;">65%</div>
                    </div>
                    <div style="text-align: center;">
                        <i class="fas fa-compress-alt"></i>
                        <div style="font-size: 12px;">Pressure</div>
                        <div style="font-weight: 600;">1012 hPa</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <div>© 2026 AzureSphere Connectivity Lab • Docker + Nginx + SFTP</div>
        <div class="footer-links">
            <a href="#"><i class="fab fa-github"></i></a>
            <a href="#"><i class="fas fa-chart-bar"></i> Metrics</a>
            <a href="#"><i class="fas fa-cog"></i> Settings</a>
            <a href="#"><i class="fas fa-question-circle"></i> Help</a>
        </div>
    </div>
</div>

<script>
// Enhanced Live Data Simulation
function updateDashboard() {
    // Traffic stats
    const requests = Math.floor(Math.random() * 8500) + 1500;
    const connections = Math.floor(Math.random() * 350) + 50;
    
    document.getElementById("requests").innerText = requests.toLocaleString();
    document.getElementById("connections").innerText = connections;
    document.getElementById("totalConnections").innerText = connections;
    document.getElementById("requestsPerMin").innerText = Math.floor(Math.random() * 500) + 200;
    
    // Uptime calculation (simulated)
    const uptimeDays = Math.floor(Math.random() * 30) + 15;
    const uptimeHours = Math.floor(Math.random() * 24);
    document.getElementById("uptime").innerText = `${uptimeDays}d ${uptimeHours}h`;
}

// Live clock
function updateClock() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit',
        hour12: true 
    });
    const dateString = now.toLocaleDateString('en-US', { 
        month: 'short', 
        day: 'numeric',
        year: 'numeric'
    });
    document.querySelector('#liveTime span').innerText = `${dateString} ${timeString}`;
}

// Initialize
updateDashboard();
updateClock();

// Weather widget script
!function(d,s,id){
    var js,fjs=d.getElementsByTagName(s)[0];
    if(!d.getElementById(id)){
        js=d.createElement(s);js.id=id;
        js.src='https://weatherwidget.io/js/widget.min.js';
        fjs.parentNode.insertBefore(js,fjs);
    }
}(document,'script','weatherwidget-io-js');

// Auto-refresh data every 10 seconds
setInterval(updateDashboard, 10000);
setInterval(updateClock, 1000);
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
