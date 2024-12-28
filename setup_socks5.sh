#!/usr/bin/env bash
#
# 一键部署已编译好的 3proxy（无认证），并修复“启动后立即退出”问题
# 适用于 Ubuntu 系统
#
# -------------------------------------------------------------------
# 关键点:
#   - 不使用 "daemon" 指令 (3proxy 配置文件中)
#   - 不使用 "pidfile" 指令
#   - 让 3proxy 在前台运行，使得 systemd 可以检测并保持它在 active 状态
#
# 默认:
#   - 端口: 1080
#   - 无认证 (auth none)
#   - 包结构: 3proxy_package/bin/3proxy
#
# 使用:
#   1) chmod +x install_3proxy_noauth_systemd.sh
#   2) ./install_3proxy_noauth_systemd.sh
#

set -e

# 你的编译产物下载地址（带 "?raw=true" 保证直接下载）
TARBALL_URL="https://github.com/FitRTeams/ipcreate/blob/main/3proxy_package.tar.gz?raw=true"

echo ">>> [1/7] 安装必要依赖 ..."
apt-get update -y
apt-get install -y wget tar net-tools

echo ">>> [2/7] 下载并解压 3proxy_package.tar.gz 至 /usr/local/3proxy ..."
TMP_DIR="/tmp/3proxy_install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

wget -O 3proxy_package.tar.gz "$TARBALL_URL"

# 目标安装目录
INSTALL_DIR="/usr/local/3proxy"
mkdir -p "$INSTALL_DIR"

# 解压: 不使用 --strip-components，直接解到 /usr/local/3proxy
tar -xzf 3proxy_package.tar.gz -C "$INSTALL_DIR"

# 理论上会出现 /usr/local/3proxy/3proxy_package/bin/3proxy
echo ">>> [3/7] 调整解压后的目录结构 ..."

if [ -f "$INSTALL_DIR/3proxy_package/bin/3proxy" ]; then
  mv "$INSTALL_DIR/3proxy_package/bin" "$INSTALL_DIR/"
  rm -rf "$INSTALL_DIR/3proxy_package"
elif [ -f "$INSTALL_DIR/bin/3proxy" ]; then
  echo ">>> 3proxy 已在 /usr/local/3proxy/bin 下，无需移动。"
else
  echo "!!! 未找到 3proxy 主程序，请检查包内文件结构。"
  exit 1
fi

chmod +x "$INSTALL_DIR/bin/3proxy"

echo ">>> [4/7] 创建 3proxy 无认证配置 /etc/3proxy/3proxy.cfg ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 无认证配置 (Systemd前台模式)
# 注意: 不要使用 daemon 或 pidfile
# 否则 Systemd 会认为进程退出或无法追踪

# 最大连接数
maxconn 512

# DNS
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 不需要认证
auth none
allow *

# Socks5 端口: 1080
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

echo ">>> [5/7] 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server (No Auth, run in foreground)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
# 文件描述符限制
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [6/7] 启动 3proxy 并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

sleep 1
echo ">>> [7/7] 检查 3proxy 运行状态 ..."
systemctl status 3proxy --no-pager || true

echo
echo "=========================================="
echo "3proxy 已启动并以前台模式运行 (Systemd管理)"
echo "无密码 Socks5 代理: [服务器IP]:1080"
echo "=========================================="
echo
echo "如果要修改端口或配置，请编辑 /etc/3proxy/3proxy.cfg"
echo "修改后执行: systemctl restart 3proxy"
echo "Done."
