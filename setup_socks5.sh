#!/bin/bash
set -e

# 判断系统使用的包管理器，并安装依赖
if command -v apt-get >/dev/null 2>&1; then
  apt-get update && apt-get install -y build-essential git wget
elif command -v yum >/dev/null 2>&1; then
  yum install -y gcc make git wget
else
  echo "不支持当前包管理器，请手动安装 gcc/make/git/wget。"
  exit 1
fi

# 下载并编译 microsocks
if [ ! -d "microsocks" ]; then
  git clone https://github.com/rofl0r/microsocks.git
fi
cd microsocks
make
cp microsocks /usr/local/bin/
cd ..

# 配置 DNS 以改善谷歌访问问题（可能需要根据具体情况调整）
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 创建 systemd 服务文件，保证服务自启动并保持运行
cat <<'EOF' > /etc/systemd/system/microsocks.service
[Unit]
Description=Microsocks lightweight SOCKS5 proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/microsocks -p 1080 -b 0.0.0.0
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable microsocks
systemctl restart microsocks

echo "Microsocks SOCKS5 服务已部署并在 1080 端口运行。"
