#!/usr/bin/env bash

# =====================================================================
# Author: Your Name
# Description: 一键部署 3proxy SOCKS5 代理服务
# Version: 2.0
# =====================================================================

set -e

# === 1. 检查是否以 root 用户运行 ===
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 用户或通过 sudo 运行此脚本。"
    exit 1
fi

# === 2. 安装必要的依赖包 ===
echo "安装必要的依赖包..."
apt-get update -y
apt-get install -y ufw wget

# === 3. 删除现有的 /usr/local/3proxy 目录（如果存在） ===
echo "删除现有的 /usr/local/3proxy 目录（如果存在）..."
if [ -d "/usr/local/3proxy" ]; then
    systemctl stop 3proxy || true
    rm -rf /usr/local/3proxy
    echo "已删除现有的 /usr/local/3proxy 目录。"
fi

# === 4. 创建 3proxy 目录结构 ===
echo "创建 3proxy 目录结构..."
mkdir -p /usr/local/3proxy/bin
mkdir -p /usr/local/3proxy/etc
mkdir -p /usr/local/3proxy/log

# === 5. 下载并解压 3proxy 二进制包 ===
echo "下载并解压 3proxy 二进制包..."
# 替换下面的 URL 为您上传的 3proxy_package.tar.gz 的实际下载链接
DOWNLOAD_URL="https://github.com/FitRTeams/ipcreate/raw/main/3proxy_package.tar.gz"

wget -O /tmp/3proxy_package.tar.gz "$DOWNLOAD_URL"

# 检查下载是否成功
if [ ! -f "/tmp/3proxy_package.tar.gz" ]; then
    echo "错误: 下载 3proxy_package.tar.gz 失败。请检查 DOWNLOAD_URL 是否正确。"
    exit 1
fi

# 解压 bin/3proxy 到 /usr/local/3proxy/bin
tar xzvf /tmp/3proxy_package.tar.gz -C /usr/local/3proxy/bin --strip-components=1 bin/3proxy

# 确保 3proxy 可执行文件存在
if [ ! -f "/usr/local/3proxy/bin/3proxy" ]; then
    echo "错误: /usr/local/3proxy/bin/3proxy 未找到。"
    exit 1
fi

# === 6. 创建配置文件 ===
echo "创建 3proxy 配置文件..."
cat <<EOF > /usr/local/3proxy/etc/3proxy.cfg
nscache 32768

log /usr/local/3proxy/log/3proxy.log D
maxconn 32

socks -p1080

daemon
EOF

# === 7. 设置执行权限 ===
echo "设置 3proxy 可执行权限..."
chmod +x /usr/local/3proxy/bin/3proxy

# === 8. 创建 systemd 服务文件 ===
echo "创建 systemd 服务文件..."
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy SOCKS5 Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/3proxy/bin/3proxy /usr/local/3proxy/etc/3proxy.cfg
Restart=always
RestartSec=5
LimitNOFILE=65535
MemoryMax=100M
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF

# === 9. 启动并启用 3proxy 服务 ===
echo "启动并启用 3proxy 服务..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

# === 10. 配置防火墙 ===
echo "配置防火墙规则..."
# 允许 SSH 和 SOCKS5 代理端口
ufw allow 22/tcp
ufw allow 1080/tcp

# 设置默认策略
ufw default deny incoming
ufw default allow outgoing

# 启用 UFW 防火墙
echo "启用 UFW 防火墙..."
echo "y" | ufw enable

# === 11. 设置 3proxy 的内存限制 ===
echo "设置 3proxy 的内存限制..."
mkdir -p /etc/systemd/system/3proxy.service.d
cat <<EOF > /etc/systemd/system/3proxy.service.d/limit.conf
[Service]
MemoryMax=100M
EOF

# 重新加载 systemd 配置并重启服务
systemctl daemon-reload
systemctl restart 3proxy

# === 12. 清理系统 ===
echo "清理系统..."
apt-get autoremove -y
apt-get clean

# === 13. 创建并启用 Swap 文件 ===
echo "创建并启用 Swap 文件..."
SWAPFILE=/swapfile
if [ ! -f "$SWAPFILE" ]; then
    fallocate -l 1G $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    echo "Swap 文件已创建并启用。"
else
    echo "Swap 文件已存在。"
fi

# === 14. 禁用不必要的系统服务 ===
echo "禁用不必要的系统服务以节省内存..."
systemctl disable --now apport.service || true
systemctl disable --now bluetooth.service || true
# 根据需要添加更多服务
echo "已禁用不必要的系统服务。"

echo "3proxy SOCKS5 代理已成功安装并运行在端口 1080。"
