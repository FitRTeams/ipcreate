#!/bin/bash

#============================================================
#     Dante SOCKS5 一键安装/配置脚本
#     1. 自动检测/录入公网 IP
#     2. 创建 Swap 防止进程被 OOM 杀死
#     3. 安装并配置 dante-server
#     4. 适合 2 核 0.5G 服务器
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
# 1. 询问/自动检测服务器公网 IP
#-------------------------------
read -p "请输入要绑定的公网 IP 地址 (回车跳过自动检测): " PUBLIC_IP

if [ -z "$PUBLIC_IP" ]; then
  echo "尝试自动检测公网 IP ..."
  PUBLIC_IP=$(curl -s ifconfig.me)
  if [ -z "$PUBLIC_IP" ]; then
    echo "错误：自动检测公网 IP 失败，请手动输入 IP 后重新运行脚本！"
    exit 1
  else
    echo "自动检测到的公网 IP 为: $PUBLIC_IP"
  fi
else
  echo "已使用手动输入的公网 IP: $PUBLIC_IP"
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
if [ $? -eq 0 ]; then
  echo "软件包列表更新完成。"
else
  echo "更新软件包列表失败，请检查网络！"
  exit 1
fi

echo "安装必要的软件包..."
apt-get install -y -qq dante-server curl
if [ $? -eq 0 ]; then
  echo "必要软件安装完成。"
else
  echo "软件安装失败，请检查网络或源配置！"
  exit 1
fi

#------------------------
# 5. 创建并启用 Swap
#------------------------
# 说明：若服务器已有 Swap 或不需要，可注释这段
SWAP_SIZE="512M"  # 可根据需求调整大小
if free | grep -q "Swap:            0"; then
  echo "检测到系统无 Swap，开始创建 ${SWAP_SIZE} Swap ..."
  fallocate -l $SWAP_SIZE /swapfile
  if [ $? -ne 0 ]; then
    echo "创建 /swapfile 失败，请检查磁盘剩余空间或权限！"
    exit 1
  fi
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if [ $? -eq 0 ]; then
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    echo "Swap 启用成功，大小：${SWAP_SIZE}"
  else
    echo "启用 Swap 失败，请手动检查！"
  fi
else
  echo "系统已存在 Swap，无需重复创建。"
fi

#--------------------------------
# 6. 检测公网 IP 是否已绑定网卡
#--------------------------------
echo "检查公网 IP 是否已绑定到网卡 eth0..."
if ip addr show eth0 | grep -q "$PUBLIC_IP"; then
  echo "公网 IP $PUBLIC_IP 已绑定到网卡 eth0，无需重复绑定。"
else
  echo "绑定公网 IP 到网卡 eth0..."
  ip addr add $PUBLIC_IP/32 dev eth0
  if [ $? -eq 0 ]; then
    echo "公网 IP $PUBLIC_IP 绑定成功。"
  else
    echo "绑定公网 IP 失败，请检查输入的 IP 地址是否正确！"
    exit 1
  fi
fi

#---------------------------
# 7. 配置 Dante SOCKS5 服务
#---------------------------
echo "配置 SOCKS5 服务..."
cat > /etc/danted.conf <<EOF
# 关闭日志输出到文件，可改为 syslog 或 /var/log/danted.log
logoutput: /dev/null

# 监听公网 IP 和端口
internal: 0.0.0.0 port = 1080
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
# 8. 启动并设置开机自启 Dante 服务
#------------------------------------
echo "注册并启动 SOCKS5 守护进程..."
systemctl restart danted
systemctl enable danted

#--------------------------------
# 9. 验证服务状态并输出结果
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
