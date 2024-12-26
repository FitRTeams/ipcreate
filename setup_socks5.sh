#!/usr/bin/env bash
#
# Author: Your Name
# Description: 批量部署 3proxy SOCKS5 代理，配置系统优化
# Version: 1.2

set -e

# === 1. 检查是否以 root 用户运行 ===
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 用户或通过 sudo 运行此脚本。"
    exit 1
fi

# === 2. 系统更新与升级 ===
echo "更新系统包列表并升级现有包..."
apt-get update -y && apt-get upgrade -y

# === 3. 禁用不必要的服务以节省资源 ===
echo "禁用不必要的服务..."
# 移除 'ssh' 以保持 SSH 访问
SERVICES=("apache2" "ufw" "firewalld")  # 根据需要添加或移除服务
for service in "${SERVICES[@]}"; do
    if systemctl list-units --full -all | grep -Fq "$service.service"; then
        systemctl stop "$service" || true
        systemctl disable "$service" || true
        echo "已停止并禁用服务: $service"
    fi
done

# === 4. 创建并启用临时 Swap ===
echo "创建并启用临时 Swap 文件以支持编译过程..."
SWAPFILE="/swapfile_3proxy"
if [ ! -f "$SWAPFILE" ]; then
    fallocate -l 512M "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count=512
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
    echo "临时 Swap 文件已创建并启用。"
else
    echo "临时 Swap 文件已存在。"
fi

# === 5. 安装必要的依赖包 ===
echo "安装必要的依赖包..."
apt-get install -y git build-essential wget

# === 6. 下载并编译 3proxy ===
echo "下载并编译 3proxy..."
cd /usr/local/src || exit
if [ ! -d "3proxy" ]; then
    git clone https://github.com/z3APA3A/3proxy.git
fi
cd 3proxy || exit

make -f Makefile.Linux -j1

# === 7. 检查编译结果 ===
if [ ! -f "bin/3proxy" ]; then
    echo "编译失败：未找到 bin/3proxy 可执行文件。"
    echo "移除临时 Swap 文件并退出。"
    swapoff "$SWAPFILE"
    rm -f "$SWAPFILE"
    exit 1
fi

# === 8. 安装 3proxy ===
echo "安装 3proxy..."
mkdir -p /usr/local/3proxy/bin
mkdir -p /usr/local/3proxy/log
mkdir -p /usr/local/3proxy/etc

cp bin/3proxy /usr/local/3proxy/bin/
chmod +x /usr/local/3proxy/bin/3proxy

# === 9. 配置 3proxy ===
echo "配置 3proxy..."
cat <<EOF >/usr/local/3proxy/etc/3proxy.cfg
# 3proxy 配置文件

nscache 65536

# 最小化日志输出
log /dev/null D

# 最大连接数
maxconn 32

# 设置 SOCKS5 代理，监听端口 1080
socks -p1080
EOF

# === 10. 设置 systemd 服务文件 ===
echo "设置 systemd 服务文件..."
cat <<EOF >/etc/systemd/system/3proxy.service
[Unit]
Description=3proxy SOCKS5 Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/3proxy/bin/3proxy /usr/local/3proxy/etc/3proxy.cfg
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# === 11. 启动并启用 3proxy 服务 ===
echo "启动并启用 3proxy 服务..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

# === 12. 移除临时 Swap ===
echo "移除临时 Swap 文件..."
swapoff "$SWAPFILE"
rm -f "$SWAPFILE"
echo "临时 Swap 文件已移除。"

# === 13. 配置防火墙 ===
echo "配置防火墙..."
# 安装 ufw（如果尚未安装）
apt-get install -y ufw

# 允许 SSH 和 SOCKS5 代理端口
ufw allow 22/tcp
ufw allow 1080/tcp

# 设置默认策略
ufw default deny incoming
ufw default allow outgoing

# 启用 UFW 防火墙，确保默认拒绝其他入站连接
echo "y" | ufw enable
echo "防火墙已配置，允许 SSH (22) 和 SOCKS5 代理 (1080) 端口。"

# === 14. 系统资源优化 ===
echo "设置 3proxy 的内存限制..."
mkdir -p /etc/systemd/system/3proxy.service.d
cat <<EOF >/etc/systemd/system/3proxy.service.d/limit.conf
[Service]
# 限制最大内存使用为 100M
MemoryMax=100M
EOF

systemctl daemon-reload
systemctl restart 3proxy
echo "已设置 3proxy 的内存限制。"

# === 15. 清理系统 ===
echo "清理系统..."
apt-get autoremove -y
apt-get clean
echo "系统清理完成。"

echo "所有步骤已完成。3proxy SOCKS5 代理运行在端口 1080。"
