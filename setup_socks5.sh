#!/bin/bash
# 轻量级Socks5部署脚本 (microsocks)
# 适用于 Ubuntu/Debian 系统

# 检查root权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本" >&2
  exit 1
fi

# 配置参数
PORT=1080
USERNAME="web3happy"
PASSWORD="Hua123456**"
DNS_SERVER="8.8.8.8"

# 安装基础依赖
apt-get update -y
apt-get install -y wget iptables-persistent netfilter-persistent

# 下载静态编译的microsocks（已提前编译好）
BIN_URL="https://github.com/rofl0r/microsocks/releases/download/v1.1/microsocks-x86_64-linux-musl"
wget -O /usr/local/bin/microsocks "$BIN_URL"
chmod +x /usr/local/bin/microsocks

# 创建systemd服务
cat > /etc/systemd/system/microsocks.service <<EOF
[Unit]
Description=MicroSocks lightweight SOCKS5 server
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/microsocks -1 -u "$USERNAME" -P "$PASSWORD" -p $PORT
Restart=always
RestartSec=5
LimitNOFILE=65536
Environment="DNS_RESOLVER=$DNS_SERVER"

# 安全加固
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

# 优化系统配置
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
sysctl -p

# 防火墙设置（仅允许必要端口）
iptables -F
iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -j DROP
netfilter-persistent save

# 启动服务
systemctl daemon-reload
systemctl enable microsocks
systemctl start microsocks

echo "安装完成！SOCKS5地址：$(hostname -I | awk '{print $1}'):$PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
