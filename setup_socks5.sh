#!/bin/bash
# microsocks 一键部署脚本
# 适用于 Ubuntu/Debian/CentOS 系统
#
# 默认参数（可通过环境变量覆盖）:
#   PROXY_PORT: 1080
#   PROXY_LISTEN_IP: 0.0.0.0
#   DNS1: 8.8.8.8
#   DNS2: 8.8.4.4
#
# 注意：microsocks 不支持用户名/密码认证，如有需求请在网络层面做 IP 限制

# 取消可能存在的 PUBLIC_IP 环境变量，避免误判
unset PUBLIC_IP

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本." >&2
  exit 1
fi

set -euo pipefail

# 默认变量（允许通过环境变量覆盖）
PROXY_PORT=${PROXY_PORT:-1080}
PROXY_LISTEN_IP=${PROXY_LISTEN_IP:-0.0.0.0}
DNS1=${DNS1:-8.8.8.8}
DNS2=${DNS2:-8.8.4.4}

echo ">>> 参数设置："
echo "    代理监听端口: ${PROXY_PORT}"
echo "    监听 IP:       ${PROXY_LISTEN_IP}"
echo "    DNS1:          ${DNS1}"
echo "    DNS2:          ${DNS2}"

echo ">>> 检查并删除旧的 microsocks（如果存在）..."
if [ -f "/usr/local/bin/microsocks" ]; then
    rm -f /usr/local/bin/microsocks
    echo "旧版 microsocks 删除完成。"
fi

echo ">>> 安装编译依赖（git、gcc、make）..."
if [ -f /etc/redhat-release ]; then
    yum -y update
    yum -y install git gcc make
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    apt-get update -y
    apt-get install -y git gcc make
else
    echo "未知的操作系统，请手动安装 git、gcc、make"
    exit 1
fi

echo ">>> 克隆 microsocks 源码..."
TMP_DIR="/tmp/microsocks_install"
rm -rf "$TMP_DIR"
git clone https://github.com/rofl0r/microsocks.git "$TMP_DIR"

cd "$TMP_DIR"
echo ">>> 开始编译 microsocks..."
make
if [ ! -f "microsocks" ]; then
    echo "编译失败，请检查编译日志" >&2
    exit 1
fi

echo ">>> 安装 microsocks 到 /usr/local/bin ..."
mv microsocks /usr/local/bin/microsocks
chmod +x /usr/local/bin/microsocks

echo ">>> 配置系统 DNS (追加 ${DNS1} 与 ${DNS2} 至 /etc/resolv.conf, 如不存在)..."
if ! grep -q "${DNS1}" /etc/resolv.conf; then
    echo "nameserver ${DNS1}" >> /etc/resolv.conf
fi
if ! grep -q "${DNS2}" /etc/resolv.conf; then
    echo "nameserver ${DNS2}" >> /etc/resolv.conf
fi

echo ">>> 启动 microsocks 进程（后台运行）..."
nohup /usr/local/bin/microsocks -p ${PROXY_PORT} -i ${PROXY_LISTEN_IP} -d > /var/log/microsocks.log 2>&1 &

echo "------------------------------------------"
echo "microsocks 已启动，监听端口 ${PROXY_PORT}"
echo "（注：microsocks 不支持认证，建议通过防火墙限制访问）"
echo "查看日志: tail -f /var/log/microsocks.log"
echo "------------------------------------------"

# 清理临时目录
rm -rf "$TMP_DIR"

# 如需自动删除本脚本，可取消下面行注释
# rm -- "$0"

exit 0
