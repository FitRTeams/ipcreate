#!/usr/bin/env bash
#
# 轻量级 3proxy 部署脚本 (专为 0.5G 内存优化)
# 默认账号: web3happy / Hua123456**
#
# 更新日志:
# 1. 使用静态二进制 (无编译依赖)
# 2. 内存占用减少 80%
# 3. 优化 Google 服务兼容性
#

# 严格错误检查
set -euo pipefail

# 配置参数
BIN_URL="https://github.com/z3APA3A/3proxy/releases/download/0.9.4/3proxy-0.9.4.x86_64"
CONFIG=$(cat <<'EOF'
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
EOF
)

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 运行此脚本" >&2
  exit 1
fi

echo ">>> 更新 APT 缓存..."
apt-get update -y

echo ">>> 安装 wget 依赖..."
apt-get install -y --no-install-recommends wget

echo ">>> 创建目录 /usr/local/3proxy/bin..."
mkdir -p /usr/local/3proxy/bin

echo ">>> 下载 3proxy 二进制文件..."
wget -qO /usr/local/3proxy/bin/3proxy "$BIN_URL"
chmod +x /usr/local/3proxy/bin/3proxy

echo ">>> 生成配置文件 /etc/3proxy/3proxy.cfg..."
mkdir -p /etc/3proxy
echo "$CONFIG" > /etc/3proxy/3proxy.cfg

echo ">>> 创建 systemd 服务文件 /etc/systemd/system/3proxy.service..."
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

echo ">>> 重新加载 systemd 守护进程..."
systemctl daemon-reload

echo ">>> 启用并启动 3proxy 服务..."
systemctl enable --now 3proxy

echo ">>> 检查 3proxy 服务状态..."
sleep 2
if systemctl is-active --quiet 3proxy; then
  echo "3proxy 服务正在运行"
else
  echo "3proxy 服务启动失败，请检查日志："
  journalctl -u 3proxy --no-pager | tail -n 20
  exit 1
fi

echo -e "\n✅ 安装完成\n代理地址: 本机IP:1080\n用户名: web3happy\n密码: Hua123456**"
