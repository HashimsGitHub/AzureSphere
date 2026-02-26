# Dockerfile
FROM nginx:alpine

# Remove default Nginx HTML
RUN rm -rf /usr/share/nginx/html/*

# Copy your HTML from Git repo
COPY index.html /usr/share/nginx/html/index.html

# Expose HTTPS port
EXPOSE 443

# Optional: if you have SSL certs
# COPY fullchain.pem /etc/ssl/certs/fullchain.pem
# COPY privkey.pem /etc/ssl/private/privkey.pem
# COPY default.conf /etc/nginx/conf.d/default.conf

CMD ["nginx", "-g", "daemon off;"]
