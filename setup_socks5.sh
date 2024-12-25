#!/bin/bash

#============================================================
#     Dante SOCKS5 一键安装/配置脚本 - 自动检测公网 IP 版
#============================================================

echo "=============================="
echo "开始配置 SOCKS5 代理服务..."
echo "=============================="

#--------------------------
# 0. 检查是否是 root 用户
#--------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本！"
  exit 1
fi

#-------------------------------
# 1. 自动检测服务器公网 IP
#-------------------------------
echo "尝试自动检测公网 IP ..."
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
  echo "错误：自动检测公网 IP 失败，请检查网络连接后重试！"
  exit 1
else
  echo "自动检测到的公网 IP 为: $PUBLIC_IP"
fi

#-------------------------
# 2. 检查/终止已有 danted
#-------------------------
echo "检查是否存在正在运行的 danted 进程..."
if pgrep -x "danted" > /dev/null; then
  echo "发现运行中的 danted 进程，正在终止..."
  systemctl stop danted
  pkill -9 danted
  echo "已终止所有 danted 相关进程。"
else
  echo "未发现运行中的 danted 进程。"
fi

#---------------------------
# 3. 修复 apt/dpkg 锁问题
#---------------------------
echo "检查是否有占用锁的进程..."
LOCKED_PROCESSES=$(ps aux | grep -E "apt|dpkg" | grep -v grep)
if [ -n "$LOCKED_PROCESSES" ]; then
  echo "发现以下占用锁的进程，正在清理..."
  echo "$LOCKED_PROCESSES" | awk '{print $2}' | xargs kill -9
fi

echo "删除锁文件..."
rm -f /var/lib/dpkg/lock
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/cache/apt/archives/lock

echo "修复 dpkg..."
dpkg --configure -a
if [ $? -eq 0 ]; then
  echo "dpkg 修复完成。"
else
  echo "dpkg 修复失败，请手动检查！"
  exit 1
fi

#---------------------------
# 4. 更新系统并安装软件包
#---------------------------
echo "更新软件包列表..."
apt-get update -qq
if [ $? -ne 0 ]; then
  echo "更新软件包列表失败，请检查网络！"
  exit 1
fi

echo "安装必要的软件包..."
apt-get install -y -qq dante-server curl
if [ $? -ne 0 ]; then
  echo "软件安装失败，请检查网络或源配置！"
  exit 1
fi
echo "必要软件安装完成。"

#------------------------
# 5. Swap 设置（2G）
#   先检查是否已有 swap；如果有，删除并重新创建
#------------------------
SWAP_SIZE="2G"

# 5.1 关闭现有所有 Swap
echo "关闭现有的所有 Swap..."
swapoff -a

# 5.2 从 /etc/fstab 中移除任何包含 swap 的条目
echo "从 /etc/fstab 中移除 Swap 条目..."
sed -i '/swap/d' /etc/fstab

# 5.3 删除可能存在的旧 /swapfile
if [ -f /swapfile ]; then
  echo "检测到已有 /swapfile，删除之..."
  rm -f /swapfile
fi

# 5.4 创建新的 2G Swap
echo "创建 ${SWAP_SIZE} 的新 Swap..."
fallocate -l $SWAP_SIZE /swapfile
if [ $? -ne 0 ]; then
  echo "创建 /swapfile 失败，请检查磁盘剩余空间或权限！"
  exit 1
fi

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
if [ $? -ne 0 ]; then
  echo "启用 Swap 失败，请手动检查！"
  exit 1
fi

echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
echo "Swap 启用成功，大小：${SWAP_SIZE}"

#------------------------
# 6. 调整 swappiness
#   让系统更倾向于先用 Swap，再用物理内存
#------------------------
echo "设置 vm.swappiness=100 (更倾向于使用 Swap)..."
sysctl -w vm.swappiness=100 >/dev/null 2>&1

# 如果要开机生效，需要写入 /etc/sysctl.conf
if grep -q "vm.swappiness" /etc/sysctl.conf; then
  sed -i 's/^vm.swappiness=.*/vm.swappiness=100/' /etc/sysctl.conf
else
  echo "vm.swappiness=100" >> /etc/sysctl.conf
fi

#--------------------------------
# 7. 配置 Dante SOCKS5 服务
#--------------------------------
echo "配置 SOCKS5 服务..."
cat > /etc/danted.conf <<EOF
# 关闭日志输出到文件，可改为 /var/log/danted.log 或 syslog
logoutput: /dev/null

# 监听所有地址 0.0.0.0 并使用 1080 端口
internal: 0.0.0.0 port = 1080
external: $(ip route get 8.8.8.8 | awk '{print $5; exit}')

# 用户认证方式
method: none

# 用户权限
user.privileged: proxy
user.unprivileged: nobody

# 限制并发连接
maxnumberofclients: 50
maxnumberofconnections: 100

# 客户端连接规则
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# SOCKS 服务规则
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect
}
EOF
echo "SOCKS5 配置完成。"

#------------------------------------
# 8. Systemd OOM 优化：调整优先级
#------------------------------------
echo "添加 Systemd OOM 优化..."
mkdir -p /etc/systemd/system/danted.service.d
cat > /etc/systemd/system/danted.service.d/override.conf <<EOF
[Service]
# 调整 OOM 优先级，值越负越不容易被杀，默认为0
OOMScoreAdjust=-800
EOF

systemctl daemon-reload

#------------------------------------
# 9. 启动并设置开机自启 Dante 服务
#------------------------------------
echo "注册并启动 SOCKS5 守护进程..."
systemctl enable danted
systemctl restart danted

#--------------------------------
# 10. 验证服务状态并输出结果
#--------------------------------
if systemctl status danted | grep -q "active (running)"; then
  echo "SOCKS5 代理服务已启动！"
  echo "代理地址：socks5://$PUBLIC_IP:1080"
else
  echo "SOCKS5 服务启动失败，请检查配置或日志！"
  echo "最近的错误日志如下："
  journalctl -u danted --no-pager | tail -n 10
  exit 1
fi

echo "=============================="
echo "SOCKS5 代理服务配置完成！"
echo "=============================="
