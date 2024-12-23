#!/bin/bash

# 检查是否是 root 用户
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本！"
  exit 1
fi

# 输入服务器公网 IP
read -p "请输入要绑定的公网 IP 地址: " PUBLIC_IP

# 检查输入是否为空
if [ -z "$PUBLIC_IP" ]; then
  echo "错误：未输入公网 IP！"
  exit 1
fi

# 更新系统并安装依赖
echo "更新系统并安装必要的软件包..."
apt update && apt upgrade -y
apt install -y dante-server curl

# 绑定 IP 到网卡 eth0
echo "绑定公网 IP 到网卡 eth0..."
ip addr add $PUBLIC_IP/32 dev eth0

# 验证 IP 是否绑定成功
if ip addr show eth0 | grep -q "$PUBLIC_IP"; then
  echo "公网 IP $PUBLIC_IP 已成功绑定到 eth0！"
else
  echo "错误：未能绑定公网 IP，请检查输入的 IP 地址是否正确！"
  exit 1
fi

# 配置 Dante SOCKS5 服务
echo "配置 SOCKS5 代理服务..."
cat > /etc/danted.conf <<EOF
logoutput: syslog

# 监听所有 IP 和端口
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

# 开放防火墙端口
echo "配置防火墙，开放 1080 端口..."
ufw allow 1080/tcp
ufw reload

# 启动并启用 Dante 服务
echo "启动 SOCKS5 服务..."
systemctl restart danted
systemctl enable danted

# 验证服务状态并输出结果
if systemctl status danted | grep -q "active (running)"; then
  echo "SOCKS5 代理安装成功！"
  echo "代理地址：socks5://$PUBLIC_IP:1080"
else
  echo "SOCKS5 服务启动失败，请检查配置！"
fi
