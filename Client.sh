#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
mkdir /etc/cherry
mkdir /etc/cherry/ssl
sudo setenforce 0

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

read -p "请输入管理员服务器域名 (例如 example.com): " ADMINDOMAIN
read -p "请输入管理员服务器端口 (例如 8080): " ADMINPORT
# read -p "请输入管理员UUID (例如 5c0aef3de4a2da59c1a411a16f485572): " ADMINUUID


echo "正在删除现有的 SSL 证书..."
~/.acme.sh/acme.sh --remove -d $DOMAIN
# 使用 acme.sh 申请证书
if [ -z "$SUBDOMAIN" ]; then
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN


else
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN -d $SUBDOMAIN
fi

# 配置安装证书的路径（这里需要根据实际情况修改）
KEY_PATH="/etc/cherry/ssl/client.key"
CERT_PATH="/etc/cherry/ssl/client.crt"

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


#! 开始安装程序
APP_CONFIG_FILE="/etc/cherry/config.json"

# 创建 JSON 文件
sudo cat > $APP_CONFIG_FILE <<EOF
{
  "websocketHost": "auto.recoverypz4.top",
  "websocketPort": "8443",
  "adminHost": "$ADMINDOMAIN",
  "adminPort": "$ADMINPORT",
  "adminUUid": "api/ws/upload",
  "uuid": "5c0aef3de4a2da59c1a411a16f485572",
  "client_domain": "$DOMAIN"
}
EOF
echo "基础类型文件创建完成"
# 提示文件创建完成
ip_address=$(hostname -I | awk '{print $1}')





echo "开始下载并安装程序"
curl -L https://raw.githubusercontent.com/cherryreally/cherrytest/main/Client.zip -o filename.zip
# unzip ~/Client.zip -d /etc/cherry && rm -f ~/Client.zip
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

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   86400s;
    types_hash_max_size 2048;
    

    include             /etc/nginx/conf.d/*.conf;

upstream websocket_backend {
        server localhost:7799;  # 使用你的后端 WebSocket 服务器地址和端口
        keepalive 64;
    }
server {
        listen       443 ssl;
        server_name  $DOMAIN;
        ssl_certificate     $SSL_CERT_FILE;
        ssl_certificate_key $SSL_KEY_FILE;
        ssl_prefer_server_ciphers on;
        location / {
            proxy_pass http://websocket_backend;
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
     server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        return 403;
    }

    # 你的域名服务器块
    server {
        listen 80;
        server_name $DOMAIN; # 替换为你的域名
        return 301 https://\$host\$request_uri;
    }

    # 如果你使用 HTTPS，也为 HTTPS 设置默认服务器块
    server {
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        server_name _;

        # SSL 配置
        ssl_certificate     $SSL_CERT_FILE;
        ssl_certificate_key    $SSL_KEY_FILE;
        return 403;
    }  
}



EOF

echo "Nginx 配置文件已更新: $NGINX_CONFIG_FILE"

# 重新加载 Nginx 配置
sudo nginx -t && sudo systemctl reload nginx


# chmod +x /etc/cherry/app && nohup /etc/cherry/app > /etc/cherry/app.log 2>&1 &

cd /etc/cherry && chmod +x app && nohup ./app > app.log 2>&1 &

#!/bin/bash

# 定义变量
SERVICE_NAME="cherry"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
WORKING_DIR="/etc/cherry"
APP_EXECUTABLE="${WORKING_DIR}/app"
LOG_FILE="${WORKING_DIR}/app.log"

# 检查工作目录是否存在，如果不存在则创建
if [ ! -d "$WORKING_DIR" ]; then
    echo "Creating working directory: ${WORKING_DIR}"
    sudo mkdir -p "$WORKING_DIR"
fi

# 检查应用程序文件是否存在
if [ ! -f "$APP_EXECUTABLE" ]; then
    echo "Error: Application executable not found at ${APP_EXECUTABLE}"
    exit 1
fi

# 创建 systemd 服务文件
echo "Creating systemd service file: ${SERVICE_FILE}"
sudo bash -c "cat > ${SERVICE_FILE}" <<EOL
[Unit]
Description=Cherry App Service
After=network.target

[Service]
Type=simple
WorkingDirectory=${WORKING_DIR}
ExecStart=${APP_EXECUTABLE}
Restart=on-failure
StandardOutput=file:${LOG_FILE}
StandardError=file:${LOG_FILE}
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

# 设置服务文件权限
sudo chmod 644 ${SERVICE_FILE}

# 重新加载 systemd 配置
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# 启用服务（设置为开机启动）
echo "Enabling ${SERVICE_NAME} service to start on boot..."
sudo systemctl enable ${SERVICE_NAME}

# 启动服务
echo "Starting ${SERVICE_NAME} service..."
sudo systemctl start ${SERVICE_NAME}

# 检查服务状态
sudo systemctl status ${SERVICE_NAME}

echo "Service ${SERVICE_NAME} has been successfully set up and started."



echo "系统正常运行....."
rm -f ~/Client.sh
