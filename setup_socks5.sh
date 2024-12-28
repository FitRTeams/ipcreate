#!/usr/bin/env bash
#
# 一键部署已编译好的 3proxy，并设置为「无密码」Socks5 代理
# -------------------------------------------------------------------
# 默认:
#   - 监听端口: 1080
#   - 不需要用户名、密码 (auth none)
#   - 压缩包内的结构: 3proxy_package/bin/3proxy
#
# 使用:
#   1) chmod +x install_3proxy_noauth.sh
#   2) ./install_3proxy_noauth.sh
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

# 解压时不使用 --strip-components，直接解到 /usr/local/3proxy
tar -xzf 3proxy_package.tar.gz -C "$INSTALL_DIR"

# 现在理论上会有 /usr/local/3proxy/3proxy_package/bin/3proxy

echo ">>> [3/7] 调整解压后的目录结构 ..."
# 假设解压后多了一层 3proxy_package 文件夹
# 我们要找到 /usr/local/3proxy/3proxy_package/bin/3proxy 并把 bin/ 移到 /usr/local/3proxy/
if [ -f "$INSTALL_DIR/3proxy_package/bin/3proxy" ]; then
  # 把 bin/ 移到 /usr/local/3proxy/
  mv "$INSTALL_DIR/3proxy_package/bin" "$INSTALL_DIR/"
  # 删除那个多余的 3proxy_package 文件夹
  rm -rf "$INSTALL_DIR/3proxy_package"
elif [ -f "$INSTALL_DIR/bin/3proxy" ]; then
  echo ">>> 已经是正确结构，无需移动。"
else
  echo "!!! 未找到 3proxy 主程序，请用 'tar -tzf 3proxy_package.tar.gz' 检查包内结构!"
  exit 1
fi

# 最终需要 /usr/local/3proxy/bin/3proxy 存在
# 授权可执行
chmod +x "$INSTALL_DIR/bin/3proxy"

echo ">>> [4/7] 创建 3proxy 配置文件: /etc/3proxy/3proxy.cfg (无认证) ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 无密码配置示例
daemon
pidfile /var/run/3proxy.pid

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

# 启动 Socks5 服务
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

echo ">>> [5/7] 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server (No Auth)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [6/7] 启动 3proxy 并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo ">>> [7/7] 检查服务状态 ..."
sleep 1
systemctl status 3proxy --no-pager || true

echo
echo "=========================================="
echo ">>> 3proxy 安装并启动完成 (无需密码)。"
echo ">>> Socks5 代理: [服务器IP]:1080"
echo "=========================================="
echo
echo "如果要修改端口或配置，请编辑 /etc/3proxy/3proxy.cfg"
echo "修改后执行: systemctl restart 3proxy"
echo
echo "Done."
