#!/usr/bin/env bash
#
# 一键清除旧版本并重新部署新版 microsocks (SOCKS5代理 + systemd 前台模式 + 自动重启)
# 适用于 Ubuntu 系统
#
# 使用说明:
#   1) 以 root 用户运行
#   2) chmod +x install_microsocks.sh
#   3) ./install_microsocks.sh
#

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本." >&2
  exit 1
fi

echo ">>> [A] 清除旧版本的影响 ..."

# 停止并禁用旧的 microsocks 服务
systemctl stop microsocks || true
systemctl disable microsocks || true

# 删除旧的 systemd 服务文件（如果存在）
if [ -f /etc/systemd/system/microsocks.service ]; then
  rm -f /etc/systemd/system/microsocks.service
  echo "旧的 /etc/systemd/system/microsocks.service 已删除"
fi

# 杀掉任何残留的 microsocks 进程
pkill microsocks || true

# 删除旧的二进制文件（如果存在）
if [ -f /usr/local/bin/microsocks ]; then
  rm -f /usr/local/bin/microsocks
  echo "旧的 /usr/local/bin/microsocks 已删除"
fi

# 重新加载 systemd 配置
systemctl daemon-reload

echo ">>> [B] 更新系统并安装依赖 (git, build-essential) ..."
apt-get update -y
apt-get install -y git build-essential

echo ">>> [C] 配置 DNS 为 Google DNS (8.8.8.8, 8.8.4.4) ..."
cat > /etc/resolv.conf <<'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo ">>> [D] 下载并编译 microsocks ..."
TMP_DIR="/tmp/microsocks_install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"
# 克隆项目源码
git clone https://github.com/rofl0r/microsocks.git
cd microsocks
# 编译 microsocks（生成 microsocks 二进制文件）
make

echo ">>> [E] 安装 microsocks 到 /usr/local/bin ..."
install -m 755 microsocks /usr/local/bin/microsocks

echo ">>> [F] 创建 systemd 服务文件 /etc/systemd/system/microsocks.service ..."
cat > /etc/systemd/system/microsocks.service <<'EOF'
[Unit]
Description=Microsocks lightweight SOCKS5 proxy server
After=network.target

[Service]
Type=simple
# 使用 -i 指定监听IP地址, -p 指定端口号
ExecStart=/usr/local/bin/microsocks -i0.0.0.0 -p1080
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [G] 重新加载 systemd 配置并启动新服务 ..."
systemctl daemon-reload
systemctl enable microsocks
systemctl restart microsocks

echo ">>> [H] 检查 microsocks 服务状态 ..."
sleep 2
systemctl status microsocks --no-pager || true

echo ">>> [I] 检查 1080 端口监听情况 ..."
ss -tunlp | grep microsocks || true

# 清理临时目录
rm -rf "$TMP_DIR"

echo
echo "=========================================="
echo ">>> microsocks 已成功安装并启动"
echo ">>> SOCKS5 代理地址: [服务器IP]:1080"
echo "=========================================="
echo "Done."
