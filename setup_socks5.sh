#!/usr/bin/env bash
#
# 轻量级3proxy部署脚本 (专为0.5G内存优化)
# 默认账号: web3happy / Hua123456**
#
# 更新日志:
# 1. 使用静态二进制 (无编译依赖)
# 2. 内存占用减少80%
# 3. 优化Google服务兼容性
#

# 严格错误检查
set -euo pipefail

# 配置参数
BIN_URL="https://github.com/z3APA3A/3proxy/releases/download/0.9.4/3proxy-0.9.4.x86_64"
CONFIG='
nserver 8.8.8.8
nserver 1.1.1.1
nscache 0
timeouts 1 3 5 10 30 60 15 30
auth strong
users web3happy:CL:Hua123456**
allow web3happy
socks -p1080 -i0.0.0.0 -e0.0.0.0 -4
maxconn 50
external
'

# 检查root
[ "$EUID" -ne 0 ] && echo "请以root运行" >&2 && exit 1

echo ">>> 安装依赖..."
apt-get update -y
apt-get install -y --no-install-recommends wget

echo ">>> 下载二进制..."
mkdir -p /usr/local/3proxy/bin
wget -qO /usr/local/3proxy/bin/3proxy "$BIN_URL"
chmod +x /usr/local/3proxy/bin/3proxy

echo ">>> 生成配置文件..."
mkdir -p /etc/3proxy
echo "$CONFIG" > /etc/3proxy/3proxy.cfg

echo ">>> 创建systemd服务..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=Ultralight 3Proxy SOCKS5
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
LimitNOFILE=51200
MemoryMax=50M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

echo ">>> 启动服务..."
systemctl daemon-reload
systemctl enable --now 3proxy

echo ">>> 验证启动状态..."
sleep 2
systemctl status 3proxy --no-pager | grep "active (running)"

echo -e "\n✅ 安装完成\n代理地址: 本机IP:1080\n用户名: web3happy\n密码: Hua123456**"
