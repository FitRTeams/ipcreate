#!/usr/bin/env bash
#
# 一键部署 3proxy (用户名密码 + systemd前台模式 + 优化)
# 适用于 Ubuntu 系统
#
# 默认账号: web3happy
# 默认密码: Hua123456**
#
# 使用说明:
#   1) 以 root 身份运行
#   2) chmod +x install_3proxy.sh
#   3) ./install_3proxy.sh
#
# 修改配置请编辑 /etc/3proxy/3proxy.cfg 后执行:
#   systemctl restart 3proxy
#

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本." >&2
  exit 1
fi

# 更严格的Bash设置
set -euo pipefail

TARBALL_URL="https://github.com/FitRTeams/ipcreate/blob/main/3proxy_package.tar.gz?raw=true"

echo ">>> [1/8] 更新系统并安装依赖 ..."
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

echo ">>> [3/8] 调整目录结构 ..."
if [ -f "$INSTALL_DIR/3proxy_package/bin/3proxy" ]; then
  mv "$INSTALL_DIR/3proxy_package/bin" "$INSTALL_DIR/"
  rm -rf "$INSTALL_DIR/3proxy_package"
elif [ -f "$INSTALL_DIR/bin/3proxy" ]; then
  echo ">>> 已检测到 /usr/local/3proxy/bin/3proxy，无需移动。"
else
  echo "!!! 未找到 3proxy 主程序，请检查包内文件结构。" >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/bin/3proxy"

echo ">>> [4/8] 创建 /etc/3proxy/3proxy.cfg 配置文件 ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<'EOF'
# 3proxy 配置 (用户名密码 + 前台运行)
maxconn 200

# DNS 设置
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 可选日志（流量大时可能增加I/O负载）
# log /var/log/3proxy.log
# logformat "L%Y-%m-%d %H:%M:%S %p %E %I %O %n:%m"

# 使用强认证（用户名密码）
auth strong

# 定义用户 (CL表示明文密码)
users web3happy:CL:Hua123456**

# 允许认证用户访问
allow web3happy

# 启动Socks5代理，监听所有IP的1080端口
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

echo ">>> [5/8] 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server (Auth + Foreground)
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [6/8] 启动服务并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo ">>> [7/8] 等待几秒检查服务状态 ..."
sleep 2
systemctl status 3proxy --no-pager || true

echo ">>> [8/8] 检查端口监听 (1080端口) ..."
ss -tunlp | grep 3proxy || true

# 清理临时目录
rm -rf "$TMP_DIR"

echo
echo "=========================================="
echo ">>> 3proxy 已安装并启动"
echo ">>> Socks5 代理: [服务器IP]:1080"
echo ">>> 用户名: web3happy"
echo ">>> 密码:   Hua123456**"
echo
echo "可编辑 /etc/3proxy/3proxy.cfg 修改相关参数，修改后执行: systemctl restart 3proxy"
echo "=========================================="
echo "Done."
