#!/bin/bash
# 安装轻量级 SOCKS5 服务——microsocks

# 如果已有旧的 microsocks 文件，则删除
if [ -f "/usr/local/bin/microsocks" ]; then
    echo "检测到旧的 microsocks 文件，删除中..."
    rm -f /usr/local/bin/microsocks
fi

# 根据系统类型安装必要工具（git、gcc、make）
if [ -f /etc/redhat-release ]; then
    echo "CentOS 系统，更新并安装依赖..."
    yum -y update
    yum -y install git gcc make
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    echo "Debian/Ubuntu 系统，更新并安装依赖..."
    apt-get update && apt-get install -y git gcc make
else
    echo "未知的操作系统，请手动安装 git、gcc、make"
    exit 1
fi

# 克隆 microsocks 源码，并编译
if [ -d "/tmp/microsocks" ]; then
    echo "旧的源码目录存在，删除..."
    rm -rf /tmp/microsocks
fi

echo "克隆 microsocks 源码..."
git clone https://github.com/rofl0r/microsocks.git /tmp/microsocks
if [ $? -ne 0 ]; then
    echo "克隆失败，请检查网络或 GitHub 访问权限"
    exit 1
fi

cd /tmp/microsocks
echo "开始编译 microsocks..."
make
if [ ! -f "microsocks" ]; then
    echo "编译失败，请检查编译日志"
    exit 1
fi

# 将编译好的二进制文件移动到 /usr/local/bin
mv microsocks /usr/local/bin/microsocks
chmod +x /usr/local/bin/microsocks

# 配置 DNS（添加常用的 8.8.8.8，如果没有的话）
if ! grep -q "8.8.8.8" /etc/resolv.conf; then
    echo "配置 DNS 为 8.8.8.8"
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# 启动 microsocks
# 参数说明：
#   -p : 指定监听端口，这里使用 1080
#   -d : 以后台方式运行
# 如果你需要指定监听地址（例如 0.0.0.0），可以自行调整启动命令
nohup /usr/local/bin/microsocks -p 1080 -d > /var/log/microsocks.log 2>&1 &

echo "microsocks 已启动，监听 1080 端口"
