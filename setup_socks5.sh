#!/usr/bin/env bash
#
# install_3proxy_socks.sh
#
# 适用于 Ubuntu (2024 及相近版本)，在 2 核 / 0.5G 内存的服务器上
# 仅启用 SOCKS5，不需要密码认证（有安全风险！）
#
# 使用方法：
#   1) chmod +x install_3proxy_socks.sh
#   2) sudo ./install_3proxy_socks.sh
#
# 执行结束后，socks5://服务器IP:1080 无需用户名密码即可访问
#

set -e

VERSION="0.9.4"    # 3proxy 版本，可根据需要换成最新
SRC_URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/${VERSION}.tar.gz"
WORK_DIR="/tmp/3proxy-build"

echo "=== 1. 更新并安装编译所需的依赖包 ==="
apt-get update -y
apt-get install -y build-essential wget tar

echo "=== 2. 下载 3proxy 源码包（${VERSION}） ==="
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
wget -O 3proxy.tar.gz "${SRC_URL}"

echo "=== 3. 解压源码包 ==="
tar -xzf 3proxy.tar.gz
cd "3proxy-${VERSION}"

echo "=== 4. 编译 3proxy ==="
# 3proxy 源码自带不同 Makefile，可用 Makefile.Linux 进行编译
make -f Makefile.Linux

# 编译完成后可执行文件会在当前目录下的 src 里
if [[ ! -f src/3proxy ]]; then
    echo "!!! 编译失败，找不到 3proxy 可执行文件，请检查日志。"
    exit 1
fi

echo "=== 5. 安装 3proxy 到 /usr/local/bin/3proxy ==="
cp src/3proxy /usr/local/bin/3proxy
chmod +x /usr/local/bin/3proxy

echo "=== 6. 写入 3proxy 配置文件 /etc/3proxy.cfg （仅 SOCKS5、无需密码）==="
cat <<EOF >/etc/3proxy.cfg
# DNS 服务器，可根据需要修改
nserver 8.8.8.8
nserver 8.8.4.4

# 缓存大小 64K
nscache 65536

# 最大连接数
maxconn 50

# 因为不需要认证，直接允许全部流量
auth none
allow *  # 允许所有来源使用 SOCKS，存在安全风险

# 仅启用 SOCKS5，监听 1080 端口
socks -p1080
EOF

echo "=== 7. 创建 systemd 服务文件 /etc/systemd/system/3proxy.service ==="
cat <<EOF >/etc/systemd/system/3proxy.service
[Unit]
Description=3proxy tiny proxy server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/3proxy.pid
ExecStart=/usr/local/bin/3proxy /etc/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -INT \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

echo "=== 8. 重新加载 systemd 并启动 3proxy ==="
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

echo
echo "*************************************************************"
echo "* 恭喜！3proxy 已成功安装并以 SOCKS5 模式运行。           *"
echo "* SOCKS5 端口: 1080                                        *"
echo "* 无需用户名密码（注意安全风险！）                         *"
echo "* 如果要修改配置，请编辑 /etc/3proxy.cfg 后重启服务         *"
echo "*   sudo systemctl restart 3proxy                           *"
echo "*************************************************************"
