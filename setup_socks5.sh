#!/usr/bin/env bash
#
# 一键部署 3proxy (优化版)
# 适用于 Ubuntu 系统
#
# 优化重点：
# 1. 内存限制防止OOM
# 2. 连接数优化适配低配
# 3. 系统参数调优
# 4. 增强自动恢复机制
# 5. 安全加固

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本." >&2
  exit 1
fi

# 更严格的Bash设置
set -euo pipefail

TARBALL_URL="https://github.com/FitRTeams/ipcreate/blob/main/3proxy_package.tar.gz?raw=true"

echo ">>> [1/8] 系统优化准备..."
{
  # 内核参数优化 (TCP快速回收+端口重用)
  echo "net.ipv4.tcp_fin_timeout = 20" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
  sysctl -p

  # 文件描述符调整
  ulimit -n 65535
  echo "* soft nofile 65535" >> /etc/security/limits.conf
  echo "* hard nofile 65535" >> /etc/security/limits.conf
} > /dev/null

echo ">>> [2/8] 安装基础依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wget tar libssl-dev

echo ">>> [3/8] 部署3proxy..."
INSTALL_DIR="/usr/local/3proxy"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$TMP_DIR"
if ! wget -q --no-check-certificate -O 3proxy_package.tar.gz "$TARBALL_URL"; then
  echo "!!! 下载失败，请检查网络连接" >&2
  exit 1
fi

if ! tar -xzf 3proxy_package.tar.gz -C "$INSTALL_DIR" --strip-components=1; then
  echo "!!! 解压失败，请检查压缩包完整性" >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/bin/3proxy"

echo ">>> [4/8] 生成安全配置..."
mkdir -p /etc/3proxy
# 生成加密密码（示例密码：Hua123456**）
PASSWORD_CRYPT=$(openssl passwd -1 Hua123456** | grep -v '^\s*$')

cat > /etc/3proxy/3proxy.cfg <<EOF
# 安全加固配置
maxconn 100       # 降低并发连接数
nserver 1.1.1.1
nserver 8.8.8.8
nscache 0         # 禁用DNS缓存减少内存使用
timeouts 1 3 30 45 60 120 10 15
auth strong
users web3happy:CRYPT:$PASSWORD_CRYPT
allow web3happy

# 禁用日志减少I/O
#log /dev/null
daemon

# Socks5配置 (限制监听IP)
socks -p1080 -i127.0.0.1 -e$(hostname -I | awk '{print $1}')
EOF

echo ">>> [5/8] 创建加固服务..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=Hardened 3proxy Service
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=5s

# 资源限制
MemoryLimit=400M
CPUQuota=150%
Nice=10
OOMScoreAdjust=-100

# 安全沙盒
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [6/8] 启动服务..."
{
  systemctl daemon-reload
  systemctl enable --now 3proxy
  sleep 2  # 确保服务初始化
}

echo ">>> [7/8] 状态检查..."
if ! systemctl is-active --quiet 3proxy; then
  echo "!!! 服务启动失败，排查建议："
  journalctl -u 3proxy -n 20 --no-pager
  exit 1
fi

echo ">>> [8/8] 最终验证..."
if ! ss -tlnp | grep -qw 1080; then
  echo "!!! 端口监听异常"
  exit 1
fi

echo -e "\n\033[32m[部署成功]\033[0m"
echo "代理地址: $(hostname -I | awk '{print $1}'):1080"
echo "用户名: web3happy"
echo "密码: Hua123456**"
echo "监控命令: watch -n 5 'ss -s | grep 3proxy'"
