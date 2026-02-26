# Connectivity Lab

This project deploys:

- HTTPS Nginx server on port 443
- SFTP server on port 2222
    sftp -P 2222 testuser@20.11.10.72
    Password: testpassword

## Deployment

```bash
chmod +x setup.sh
./setup.sh



## Shutdown

```bash
sudo docker compose down

## Restart
sudo docker compose up


