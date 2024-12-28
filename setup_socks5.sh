#!/usr/bin/env bash
#
# 安装并配置3proxy为Socks5服务的脚本
# 适用于 Ubuntu 系统
# 默认配置:
#   - Socks5 监听端口: 1080
#   - 用户名: proxyuser
#   - 密码: proxypass
#

set -e

# 1. 更新软件源并安装必要依赖
echo ">>> 更新系统并安装依赖 ..."
apt-get update -y
apt-get install -y git gcc make build-essential wget

# 2. 下载并编译 3proxy
echo ">>> 下载并编译 3proxy ..."
# 这里示例使用3proxy官方仓库，如果需要指定版本，可改为特定tag
if [ ! -d /usr/local/src/3proxy ]; then
  git clone https://github.com/z3APA3A/3proxy.git /usr/local/src/3proxy
else
  cd /usr/local/src/3proxy && git pull
fi

cd /usr/local/src/3proxy
# 编译
make -f Makefile.Linux

# 安装(将可执行文件复制到 /usr/local/bin)
mkdir -p /usr/local/3proxy/bin
cp src/3proxy /usr/local/3proxy/bin/
cp src/3proxy.cfg /usr/local/3proxy/bin/ 2>/dev/null || true

# 3. 创建配置文件
echo ">>> 创建 3proxy 配置文件 /etc/3proxy/3proxy.cfg ..."
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
# 3proxy 主配置文件示例

# 工作目录
daemon
pidfile /var/run/3proxy.pid

# 日志配置（可选）
# log /var/log/3proxy.log
# logformat "L%Y-%m-%d %H:%M:%S %p %E %I %O %n:%m"

# 设置最大连接数（可根据实际需求调整）
maxconn 512

# 定义 Socks 代理
# 注意: 服务器本地的开放端口需确保1080是通的
# 可改为你需要的端口
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 认证方式，如果不需要认证，可以改为 "auth none"
auth strong

# 这里的用户和密码可以自行修改
users proxyuser:CL:proxypass

# 只允许已认证用户访问
allow proxyuser

# 开启socks服务，监听0.0.0.0:1080
socks -p1080 -i0.0.0.0 -e0.0.0.0
EOF

# 4. 创建 systemd service 文件，实现开机自启动
echo ">>> 创建 systemd unit 文件 /etc/systemd/system/3proxy.service ..."
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy tiny proxy server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 5. 设置开机启动并启动服务
echo ">>> 启动 3proxy 并设置开机自启 ..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 6. 检查运行状态
echo ">>> 检查 3proxy 运行状态 ..."
sleep 2
systemctl status 3proxy --no-pager || true

echo ">>> 3proxy 已安装并正在运行，Socks5 默认端口为 1080"
echo ">>> 认证用户名: proxyuser, 密码: proxypass"
echo ">>> 如需修改配置，请编辑 /etc/3proxy/3proxy.cfg 然后执行 systemctl restart 3proxy"
echo ">>> 完成。"
