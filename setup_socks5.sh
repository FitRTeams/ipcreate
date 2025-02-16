#!/bin/bash
#
# 安装并配置 microsocks 的脚本
# 建议使用 root 用户执行。如果不是 root，请在相关命令前加 sudo。

set -e

echo "开始安装 microsocks..."

# 1. 更新软件源并安装必要依赖
apt-get update -y
apt-get install -y git build-essential

# 2. 下载并编译 microsocks
[ -d /tmp/microsocks ] && rm -rf /tmp/microsocks
cd /tmp
git clone https://github.com/rofl0r/microsocks.git
cd microsocks
make

# 3. 安装编译好的可执行文件到 /usr/local/bin
cp microsocks /usr/local/bin/microsocks

# 4. 创建 systemd 服务文件，以便开机自启动
cat <<EOF >/etc/systemd/system/microsocks.service
[Unit]
Description=Microsocks - tiny, lightweight SOCKS5 server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/microsocks -p 1080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 5. 启用并启动 microsocks
systemctl daemon-reload
systemctl enable microsocks
systemctl restart microsocks

# 6. 备份并修改 DNS（写入 8.8.8.8、8.8.4.4）
if [ -f /etc/resolv.conf ]; then
  cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%F-%H-%M-%S)
fi

cat <<DNSCONF >/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
DNSCONF

echo "microsocks 安装与配置完成。"
