#!/bin/bash

#-------------------------
# 0. 开始信息 & root 检查
#-------------------------
echo "=============================="
echo "开始配置 SOCKS5 代理服务..."
echo "=============================="

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本！"
  exit 1
fi

#---------------------------------
# 1. 自动检测服务器公网 IP
#---------------------------------
echo "尝试自动检测公网 IP ..."
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
  echo "错误：自动检测公网 IP 失败，请检查网络连接后重试！"
  exit 1
else
  echo "检测到的公网 IP: $PUBLIC_IP"
fi

#-------------------------
# 2. 检查并终止已有 Dante
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
# 3. 修复 dpkg/apt 锁问题
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
if [ $? -ne 0 ]; then
  echo "dpkg 修复失败，请手动检查！"
  exit 1
fi

#---------------------------
# 4. 更新系统/安装软件包
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

#--------------------------------
# 5. 如果需要，将公网 IP 绑定到网卡
#   (适用于真实独立服务器/静态IP场景)
#--------------------------------
echo "检查公网 IP 是否已绑定到网卡 eth0..."
if ip addr show eth0 | grep -q "$PUBLIC_IP"; then
  echo "公网 IP $PUBLIC_IP 已绑定到网卡 eth0，无需重复绑定。"
else
  echo "绑定公网 IP $PUBLIC_IP 到网卡 eth0..."
  ip addr add $PUBLIC_IP/32 dev eth0
  if [ $? -ne 0 ]; then
    echo "绑定公网 IP 失败，请检查输入的 IP 地址或网络环境！"
    exit 1
  else
    echo "公网 IP $PUBLIC_IP 绑定成功。"
  fi
fi

#-------------------------
# 6. 设置 2G Swap
#-------------------------
SWAP_SIZE="2G"

echo "检查并关闭现有 Swap..."
swapoff -a

echo "从 /etc/fstab 中移除 Swap 条目..."
sed -i '/swap/d' /etc/fstab

if [ -f /swapfile ]; then
  echo "检测到已有 /swapfile，删除之..."
  rm -f /swapfile
fi

echo "创建 ${SWAP_SIZE} Swap 文件..."
fallocate -l $SWAP_SIZE /swapfile
if [ $? -ne 0 ]; then
  echo "创建 /swapfile 失败，请检查磁盘空间或权限！"
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

#-------------------------
# 7. 优先使用 Swap
#-------------------------
echo "设置 vm.swappiness=100 (更倾向于使用 Swap)..."
sysctl -w vm.swappiness=100 >/dev/null 2>&1
if grep -q "vm.swappiness" /etc/sysctl.conf; then
  sed -i 's/^vm.swappiness=.*/vm.swappiness=100/' /etc/sysctl.conf
else
  echo "vm.swappiness=100" >> /etc/sysctl.conf
fi

#------------------------------------
# 8. 配置 Dante (SOCKS5) 服务
#------------------------------------
echo "配置 SOCKS5 服务..."
cat > /etc/danted.conf <<EOF
# 将日志输出到 syslog
logoutput: syslog

# 监听:  0.0.0.0:1080 (对外提供代理)
internal: 0.0.0.0 port = 1080

# 指定对外出口为网卡 eth0
external: eth0

# 无需认证
method: username none

# 用户权限
user.privileged: proxy
user.unprivileged: nobody

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
# 9. Systemd OOM 优化
#    减少被内存回收机制杀掉几率
#------------------------------------
echo "添加 Systemd OOM 优化..."
mkdir -p /etc/systemd/system/danted.service.d
cat > /etc/systemd/system/danted.service.d/override.conf <<EOF
[Service]
OOMScoreAdjust=-800
EOF

systemctl daemon-reload

#--------------------------------
# 10. 启动并设置开机自启 Dante
#--------------------------------
echo "注册并启动 SOCKS5 守护进程..."
systemctl restart danted
systemctl enable danted

#--------------------------------
# 11. 验证服务状态并输出结果
#--------------------------------
if systemctl status danted | grep -q "active (running)"; then
  echo "SOCKS5 代理服务已启动！"
  echo "代理地址：socks5://$PUBLIC_IP:1080"
else
  echo "SOCKS5 服务启动失败，请检查配置或日志！"
  echo "最近的错误日志如下："
  journalctl -u danted | tail -n 10
  exit 1
fi

echo "=============================="
echo "SOCKS5 代理服务配置完成！"
echo "=============================="
