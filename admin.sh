#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
mkdir /etc/cherry
mkdir /etc/cherry/ssl
# 安装必要的工具
echo "正在检查并安装必要的工具..."


if ! command -v curl > /dev/null; then
    echo "正在安装 curl..."
    sudo yum install curl -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install curl -y
fi

if ! command -v iptables > /dev/null; then
    echo "正在安装 iptables..."
    sudo yum install iptables -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install curl -y
fi


if ! command -v unzip > /dev/null; then
    echo "正在安装 unzip..."
    sudo yum install unzip -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install curl -y
fi



if ! command -v jq > /dev/null; then
    echo "正在安装 jq..."
    sudo yum install jq -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install jq -y
fi

# 检查并安装 Nginx
if ! command -v nginx > /dev/null; then
    echo "Nginx 未安装。正在安装 Nginx..."
    sudo yum install nginx -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install nginx -y

    # 启动 Nginx 服务并设置开机自启
    sudo systemctl start nginx
    sudo systemctl enable nginx
fi


# 安装 MySQL
echo "Installing MySQL server..."
if sudo yum install -y mysql-server; then
  echo "MySQL server installed successfully."
else
  echo "Failed to install MySQL server."
  exit 1
fi
# 启用 MySQL 开机自启
echo "Enabling MySQL to start on boot..."
if sudo systemctl enable mysqld; then
  echo "MySQL service enabled to start on boot successfully."
else
  echo "Failed to enable MySQL service to start on boot."
  exit 1
fi
# 启动 MySQL 服务
echo "Starting MySQL service..."
if sudo systemctl start mysqld; then
  echo "MySQL service started successfully."
else
  echo "Failed to start MySQL service."
  exit 1
fi

# 设置 MySQL root 用户的密码
NEW_PASSWORD='123456'
echo "Setting MySQL root user password..."
if sudo mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '${NEW_PASSWORD}';"; then
  echo "MySQL root user password set successfully."
else
  echo "Failed to set MySQL root user password."
  exit 1
fi

# 允许 root 用户通过密码登录
echo "Flushing MySQL privileges..."
if sudo mysql -uroot -p"${NEW_PASSWORD}" -e "FLUSH PRIVILEGES;"; then
  echo "MySQL privileges flushed successfully."
else
  echo "Failed to flush MySQL privileges."
  exit 1
fi

# 检查并创建数据库 admin_cherry
echo "Checking if database 'admin_cherry' exists..."
if ! sudo mysql -uroot -p"${NEW_PASSWORD}" -e "USE admin_cherry;" 2>/dev/null; then
  echo "Database 'admin_cherry' does not exist. Creating now..."
  if sudo mysql -uroot -p"${NEW_PASSWORD}" -e "CREATE DATABASE admin_cherry;"; then
    echo "Database 'admin_cherry' created successfully."
  else
    echo "Failed to create database 'admin_cherry'."
    exit 1
  fi
else
  echo "Database 'admin_cherry' already exists."
fi

# 配置 MySQL 仅监听本地连接
echo "Configuring MySQL to bind to localhost only..."
if grep -q "^bind-address" /etc/my.cnf; then
  sudo sed -i "s/^bind-address.*/bind-address = 127.0.0.1/" /etc/my.cnf
else
  echo "bind-address = 127.0.0.1" | sudo tee -a /etc/my.cnf
fi

# 重启 MySQL 服务以应用配置
echo "Restarting MySQL service to apply new configuration..."
if sudo systemctl restart mysqld; then
  echo "MySQL service restarted successfully."
else
  echo "Failed to restart MySQL service."
  exit 1
fi



# 显示 MySQL 服务状态
echo "Checking MySQL service status..."
if sudo systemctl is-active mysqld; then
  echo "MySQL service is running."
else
  echo "MySQL service is not running."
  exit 1
fi


#!/bin/bash

if ! command -v socat > /dev/null; then
    echo "Socat 未安装。正在安装 Socat..."
    sudo yum install socat -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install socat -y
fi

echo "正在安装 acme.sh..."
curl https://get.acme.sh | sh

# 提示用户输入 Cloudflare 的 API 密钥和邮箱地址
read -p "请输入 Cloudflare 的 API 密钥: " CF_API_KEY
read -p "请输入 Cloudflare 的邮箱地址: " CF_EMAIL

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 将 API 密钥和邮箱地址导出为环境变量
export CF_Key="$CF_API_KEY"
export CF_Email="$CF_EMAIL"

# 提示用户输入域名
read -p "请输入您的域名 (例如 example.com): " DOMAIN
read -p "请输入您的子域名（如果有，例如 www.example.com，没有则留空）: " SUBDOMAIN
echo "正在删除现有的 SSL 证书..."
~/.acme.sh/acme.sh --remove -d $DOMAIN
# 使用 acme.sh 申请证书
if [ -z "$SUBDOMAIN" ]; then
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN


else
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN -d $SUBDOMAIN
fi

# 配置安装证书的路径（这里需要根据实际情况修改）
KEY_PATH="/etc/cherry/ssl/$DOMAIN.key"
CERT_PATH="/etc/cherry/ssl/$DOMAIN.crt"

# 安装证书
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
--key-file $KEY_PATH \
--fullchain-file $CERT_PATH

echo "密钥文件保存在: $KEY_PATH"
echo "证书文件保存在: $CERT_PATH"
#!/bin/bash


# SSL 证书和密钥的路径
SSL_CERT_FILE="$CERT_PATH"
SSL_KEY_FILE="$KEY_PATH"




# 提示文件创建完成
ip_address=$(hostname -I | awk '{print $1}')

#!/bin/bash

# 检查 SELinux 状态
SELINUX_STATUS=$(getenforce)

# 如果 SELinux 是启用状态，则禁用
if [ "$SELINUX_STATUS" == "Enforcing" ] || [ "$SELINUX_STATUS" == "Permissive" ]; then
    echo "SELinux is currently $SELINUX_STATUS. Disabling SELinux..."
    sudo setenforce 0

    # 确认禁用结果
    NEW_STATUS=$(getenforce)
    if [ "$NEW_STATUS" == "Disabled" ] || [ "$NEW_STATUS" == "Permissive" ]; then
        echo "SELinux has been disabled. Current status: $NEW_STATUS"
    else
        echo "Failed to disable SELinux. Current status: $NEW_STATUS"
    fi
else
    echo "SELinux is already disabled."
fi


echo "开始下载并安装程序"
curl -L https://raw.githubusercontent.com/cherryreally/cherrytest/main/admin.zip -o filename.zip
unzip ~/filename.zip -d /etc/cherry && rm -f ~/filename.zip

sudo rm -f /etc/nginx/nginx.conf
# 定义 nginx 主配置文件的路径
NGINX_CONFIG_FILE="/etc/nginx/nginx.conf"


# 创建 Nginx 主配置文件
sudo cat > $NGINX_CONFIG_FILE <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   86400s;  
    types_hash_max_size 2048;

    include             /etc/nginx/conf.d/*.conf;

    # HTTPS server block for secure connections on port 8443
    server {
        listen       8443 ssl;
        server_name  $DOMAIN;

        ssl_certificate     $SSL_CERT_FILE;
        ssl_certificate_key $SSL_KEY_FILE;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_read_timeout 86400s;  
            proxy_send_timeout 86400s;  
            proxy_connect_timeout 86400s; 
        }
    }

    # Redirect all HTTP requests to HTTPS on port 8443
    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://$host:8443$request_uri;
    }
}

EOF

echo "Nginx 配置文件已更新: $NGINX_CONFIG_FILE"

# 重新加载 Nginx 配置
sudo nginx -t && sudo systemctl reload nginx


# chmod +x /etc/cherry/app && nohup /etc/cherry/app > /etc/cherry/app.log 2>&1 &

cd /etc/cherry && chmod +x app && nohup ./app > app.log 2>&1 &
echo "后台地址：https://$DOMAIN:8443/login"
