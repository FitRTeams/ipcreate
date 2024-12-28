#!/usr/bin/env bash
#
# 一键部署已编译好的 3proxy 并设置为无密码 Socks5 代理
# 适用于 Ubuntu 系统
#
# -------------------------------------------------------------------
# 默认:
#   - Socks5 监听端口: 1080
#   - 无需用户名密码 (auth none)
#   - 二进制程序来源: 你的GitHub上编译好的 3proxy_package.tar.gz
#
# 使用:
#   1) chmod +x install_3proxy_noauth.sh
#   2) ./install_3proxy_noauth.sh
#

set -e

# 你在 GitHub 上提供的 tar 包下载地址 (可按需修改)
TARBALL_URL="https://github.com/FitRTeams/ipcreate/blob/main/3proxy_package.tar.gz?raw=true"

echo ">>> [1/6] 安装必要依赖 ..."
apt-get update -y
apt-get install -y wget tar net-tools

echo ">>> [2/6] 下载并解压 3proxy_package.tar.gz ..."
# 临时存放
TMP_DIR="/tmp/3proxy_install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# 下载并重命名为 3proxy_package.tar.gz
wget -O 3proxy_package.tar.gz "$TARBALL_URL"

# 安装目录
INSTALL_DIR="/usr/local/3proxy/bin"
mkdir -p "$INSTALL_DIR"

# 解压到 /usr/local/3proxy/bin
tar -xzf 3proxy_package.tar.gz -C "$INSTALL_DIR"

# 确保可执行权限
chmod +x "$INSTALL_DIR/3proxy"

echo ">>> [3/6] 创建 3proxy 配置文件: /etc/3proxy/3proxy.cfg (无需密码) ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 无密码配置示例
daemon
pidfile /var/run/3proxy.pid

# 最大连接数
maxconn 512

# DNS配置
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 不需要认证
auth none
allow *

# 启动 Socks5 服务，监听 0.0.0.0:1080
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

echo ">>> [4/6] 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server (No Auth)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [5/6] 启动 3proxy 服务并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo ">>> [6/6] 检查服务状态 ..."
sleep 1
systemctl status 3proxy --no-pager || true

echo
echo ">>> 3proxy 已经安装并启动 (无需密码)。"
echo "    Socks5 代理: [本机IP]:1080"
echo
echo ">>> 如果要修改端口或其他配置，请编辑 /etc/3proxy/3proxy.cfg 后，再执行:"
echo "    systemctl restart 3proxy"
echo
echo ">>> Done."
