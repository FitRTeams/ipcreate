#!/usr/bin/env bash
#
# install_3proxy.sh
# 
# 适用于 Ubuntu (2024 及相近版本)，在 2 核 / 0.5G 内存的服务器上启动一个轻量级的代理服务
# 
# 使用方法：
#   1) chmod +x install_3proxy.sh
#   2) sudo ./install_3proxy.sh
#
# 脚本执行结束后，会在 http://服务器IP:3128 和 socks5://服务器IP:1080 启动代理
# 默认用户 testuser，密码 testpass
#

set -e

echo "=== 1. 更新 apt 软件源列表 ==="
apt-get update -y

echo "=== 2. 安装 3proxy ==="
apt-get install -y 3proxy

echo "=== 3. 创建/覆盖 3proxy 的配置文件 /etc/3proxy.cfg ==="
cat <<EOF >/etc/3proxy.cfg
# DNS 服务器，可根据自己需要修改
nserver 8.8.8.8
nserver 8.8.4.4

# 缓存大小设为 64K
nscache 65536

# 最大连接数
maxconn 50

# 用户名密码配置 (CL 表示明文存储密码)
users testuser:CL:testpass

# 认证方式
auth strong

# 允许 testuser 使用
allow testuser


# 启动 SOCKS5 代理，监听 1080 端口
socks -p1080
EOF

echo "=== 4. 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ==="
cat <<EOF >/etc/systemd/system/3proxy.service
[Unit]
Description=3proxy tiny proxy server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/3proxy.pid
ExecStart=/usr/bin/3proxy /etc/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -INT \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

echo "=== 5. 重新加载 systemd 守护进程并启动服务 ==="
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

echo "=== 6. 检查 3proxy 服务状态 ==="
systemctl status 3proxy --no-pager

echo
echo "*************************************************************"
echo "* 恭喜！3proxy 已成功安装并启动。                        *"
echo "* 默认 HTTP 代理端口: 3128                                 *"
echo "* 默认 SOCKS5 代理端口: 1080                               *"
echo "* 默认用户名: testuser，默认密码: testpass                 *"
echo "* 如需修改请直接编辑 /etc/3proxy.cfg 并重启 3proxy          *"
echo "*************************************************************"
