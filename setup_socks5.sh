#!/bin/bash
set -e

# 安装编译依赖
apt-get update && apt-get install -y gcc make

# 编译安装microsocks
wget https://github.com/rofl0r/microsocks/archive/refs/tags/v1.1.1.tar.gz
tar xzf v1.1.1.tar.gz
cd microsocks-1.1.1
make && mv microsocks /usr/local/bin/

# 创建系统服务
cat > /etc/systemd/system/microsocks.service <<EOF
[Unit]
Description=MicroSocks SOCKS5 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/microsocks -p 1080
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable --now microsocks

# 防火墙设置（如果启用）
if command -v ufw &> /dev/null; then
    ufw allow 1080/tcp
    ufw reload
fi
