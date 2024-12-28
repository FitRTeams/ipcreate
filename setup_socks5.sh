#!/usr/bin/env bash
#
# 一键部署 3proxy (用户名密码 + systemd前台模式 + 优化)
# 适用于 Ubuntu 系统
#
# 用户名: web3happy
# 密码:   Hua123456**
#
# -------------------------------------------------------------------
# 说明:
#   - maxconn 10 (可改小或改大, 如果要单连接,可改成1)
#   - auth strong => 用户名密码
#   - 不使用 daemon/pidfile, 交由 systemd 管理(前台模式)
#   - 如果要清空现有连接, 可直接 systemctl restart 3proxy
#
# 使用:
#   1) chmod +x install_3proxy_auth_systemd.sh
#   2) ./install_3proxy_auth_systemd.sh
#

set -e

TARBALL_URL="https://github.com/FitRTeams/ipcreate/blob/main/3proxy_package.tar.gz?raw=true"

echo ">>> [1/8] 安装必要依赖 ..."
apt-get update -y
apt-get install -y wget tar net-tools

echo ">>> [2/8] 下载并解压 3proxy_package.tar.gz 到 /usr/local/3proxy ..."
TMP_DIR="/tmp/3proxy_install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

wget -O 3proxy_package.tar.gz "$TARBALL_URL"

INSTALL_DIR="/usr/local/3proxy"
mkdir -p "$INSTALL_DIR"

tar -xzf 3proxy_package.tar.gz -C "$INSTALL_DIR"

echo ">>> [3/8] 调整解压目录结构 ..."
if [ -f "$INSTALL_DIR/3proxy_package/bin/3proxy" ]; then
  mv "$INSTALL_DIR/3proxy_package/bin" "$INSTALL_DIR/"
  rm -rf "$INSTALL_DIR/3proxy_package"
elif [ -f "$INSTALL_DIR/bin/3proxy" ]; then
  echo ">>> 已检测到 /usr/local/3proxy/bin/3proxy，无需移动。"
else
  echo "!!! 未找到 3proxy 主程序，请检查包内文件结构。"
  exit 1
fi

chmod +x "$INSTALL_DIR/bin/3proxy"

echo ">>> [4/8] 创建 /etc/3proxy/3proxy.cfg (带用户名密码) ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 配置 (带用户名密码 + 前台模式)
# -------------------------------------------------
# 不使用 daemon/pidfile，让 systemd 能够保持它在前台运行。
# maxconn 10: 一次最多允许同时建立10个连接。可酌情调整。

maxconn 10

# DNS
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 可选日志, 若流量大会增加IO负载,可注释
# log /var/log/3proxy.log
# logformat "L%Y-%m-%d %H:%M:%S %p %E %I %O %n:%m"

# 认证方式: strong => 用户名密码
auth strong

# 定义用户 (CL表示明文)
users web3happy:CL:Hua123456**

# 允许已认证用户
allow web3happy

# 启动 Socks5, 监听0.0.0.0:1080
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

echo ">>> [5/8] 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server (Auth + Foreground)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [6/8] 启动 3proxy 并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo ">>> [7/8] 等待片刻后检查状态 ..."
sleep 2
systemctl status 3proxy --no-pager || true

echo ">>> [8/8] 查看端口监听情况 (若无结果则说明 1080 未监听) ..."
ss -tunlp | grep 3proxy || true

echo
echo "=========================================="
echo ">>> 3proxy (带用户名密码) 已安装并启动"
echo ">>> Socks5 代理: [服务器IP]:1080"
echo ">>> 用户名: web3happy"
echo ">>> 密码:   Hua123456**"
echo
echo "可编辑 /etc/3proxy/3proxy.cfg 修改端口、用户名、密码、maxconn 等"
echo "修改后执行: systemctl restart 3proxy"
echo "=========================================="
echo "Done."
