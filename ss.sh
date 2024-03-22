#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
mkdir /etc/cherry
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

if ! command -v redis-server > /dev/null; then
    echo "Redis 未安装。正在安装 Redis..."
    sudo yum install redis -y # CentOS/RHEL
    # 对于 Ubuntu/Debian: sudo apt-get install redis-server -y

    # 启动 Redis 服务并设置开机自启
    sudo systemctl start redis
    sudo systemctl enable redis
fi

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
KEY_PATH="$SCRIPT_DIR/$DOMAIN.key"
CERT_PATH="$SCRIPT_DIR/$DOMAIN.crt"

# 安装证书
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
--key-file $KEY_PATH \
--fullchain-file $CERT_PATH

echo "密钥文件保存在: $KEY_PATH"
echo "证书文件保存在: $CERT_PATH"
#!/bin/bash


# SSL 证书和密钥的路径
SSL_CERT_FILE="/root/$CERT_PATH"
SSL_KEY_FILE="/root/$KEY_PATH"

#!/bin/bash


#! 开始安装程序
read -p "请输入限制访问次数 (例如 30): " Visits
while ! [[ "$Visits" =~ ^[0-9]+$ ]]; do
    echo "输入不合法，请输入数字。"
    read -p "请输入限制访问次数 (例如 30): " Visits
done

read -p "请输入开放国家 (例如 CN,JP): " country
read -p "请输入要跳转的地址 (例如 https://www.baidu.com): " CPCurl
read -p "请输入接口密钥 (例如 55kAdfrbon4v9n41): " ipRegistry

# 创建 config.json 文件
APP_CONFIG_FILE="/etc/cherry/config.json"
sudo cat > $APP_CONFIG_FILE <<EOF
{
  "websocketHost": "$DOMAIN",
  "websocketPort": "9878",
  "redSwitch": 1,
  "Visits": $Visits,
  "country": "$country",
  "CPCurl": "$CPCurl",
  "ipRegistry": "$ipRegistry",
  "uuid":      "5c0aef3de4a2da59c1a411a16f485572",
  "TGAPi":     "",
  "TGChatId":  ""
}
EOF




echo "开始下载并安装程序"
curl -L https://raw.githubusercontent.com/cherryreally/cherrytest/main/t.zip -o filename.zip
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
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/conf.d/*.conf;

    server {
        listen       443 ssl;
       
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
SERVICE_FILE="/etc/systemd/system/app.service"

echo "[Unit]
Description=My App Service
After=network.target

[Service]
WorkingDirectory=/etc/cherry
ExecStart=/bin/bash -c './app'
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_FILE


sudo systemctl daemon-reload

sudo systemctl enable app.service


echo "开机自启动已开启,SUCCESS"


