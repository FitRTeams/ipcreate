#!/usr/bin/env bash
#
# 一键安装/编译 3proxy 并配置为 Socks5 服务的脚本
# 适用于 Ubuntu 系统
# -------------------------------------------------------------------
# 默认:
#   - Socks5 监听端口: 1080
#   - 用户名: proxyuser
#   - 密码: proxypass
#
# 使用:
#   1) chmod +x install_3proxy_socks5.sh
#   2) ./install_3proxy_socks5.sh
#

set -e

# ----- Step 1: 安装依赖 -----
echo ">>> [1/6] 安装系统依赖 ..."
apt-get update -y
apt-get install -y \
  gcc g++ make build-essential git \
  libpcre3 libpcre3-dev libssl-dev zlib1g-dev \
  net-tools

# ----- Step 2: 拉取3proxy源码并编译 -----
echo ">>> [2/6] 下载并编译 3proxy ..."

# 目标源码目录
INSTALL_SRC="/usr/local/src/3proxy"

# 如果已存在，先尝试更新
if [ -d "$INSTALL_SRC" ]; then
  cd "$INSTALL_SRC"
  git pull
else
  git clone https://github.com/z3APA3A/3proxy.git "$INSTALL_SRC"
  cd "$INSTALL_SRC"
fi

# 执行编译
make -f Makefile.Linux -j2 || {
  echo "!!! 编译失败，请检查错误信息。"
  exit 1
}

# ----- Step 3: 安装可执行文件 -----
echo ">>> [3/6] 安装 3proxy 主程序至 /usr/local/3proxy/bin ..."

# 创建存放3proxy的安装目录
mkdir -p /usr/local/3proxy/bin

# 新版3proxy编译后可执行文件在 bin/ 目录下
# 旧版可能在 src/，这里做个简单判断
if [ -f "${INSTALL_SRC}/bin/3proxy" ]; then
  cp "${INSTALL_SRC}/bin/3proxy" /usr/local/3proxy/bin/
elif [ -f "${INSTALL_SRC}/src/3proxy" ]; then
  cp "${INSTALL_SRC}/src/3proxy" /usr/local/3proxy/bin/
else
  echo "!!! 未找到 3proxy 主程序，请检查编译输出或路径。"
  exit 1
fi

# 如果 bin/ 目录里自带 3proxy.cfg，可一起复制（一般只是一份示例）
if [ -f "${INSTALL_SRC}/bin/3proxy.cfg" ]; then
  cp "${INSTALL_SRC}/bin/3proxy.cfg" /usr/local/3proxy/bin/ || true
fi

# ----- Step 4: 创建/覆盖 3proxy 配置文件 -----
echo ">>> [4/6] 创建 /etc/3proxy/3proxy.cfg 配置文件 ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 配置示例
# 工作目录 (daemon 模式下不支持 chroot)
daemon
pidfile /var/run/3proxy.pid

# 日志可按需启用
# log /var/log/3proxy.log
# logformat "L%Y-%m-%d %H:%M:%S %p %E %I %O %n:%m"

# 最大连接数
maxconn 512

# DNS
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 认证方式: strong => 用户名密码
auth strong

# 用户名与密码 (CL 表示明文)
users proxyuser:CL:proxypass

# 允许的用户
allow proxyuser

# 启动 Socks5 服务，监听 0.0.0.0:1080
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

# ----- Step 5: 创建 systemd 服务文件 -----
echo ">>> [5/6] 创建 systemd 服务 ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
# 限制最大文件数
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# ----- Step 6: 启动服务并检查状态 -----
echo ">>> [6/6] 启动 3proxy 服务并设为开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo
echo ">>> 安装完成！查看 3proxy 运行状态："
systemctl status 3proxy --no-pager || true

echo
echo ">>> 3proxy 已经启动并运行。"
echo "    Socks5 代理地址: [服务器IP]:1080"
echo "    用户名: proxyuser"
echo "    密码: proxypass"
echo
echo ">>> 如需更改配置，请编辑 /etc/3proxy/3proxy.cfg 后，再执行:"
echo "    systemctl restart 3proxy"
echo
echo ">>> Done."
