#!/bin/bash

# 端口判断
# 检查 9100 端口是否已经开放（精确匹配）
if sudo ss -tulnp | grep "LISTEN.*:9100"; then
    echo "端口 9100 已被监听，脚本终止"
    exit 0
fi

# 防火墙端口
# 检查firewalld是否正在运行
if systemctl is-active --quiet firewalld; then
    # 检查9100端口是否已开放
    if ! sudo firewall-cmd --list-ports | grep -q "9100/tcp"; then
        sudo firewall-cmd --add-port=9100/tcp --permanent
        sudo firewall-cmd --reload
    else
        echo "端口9100已开放，跳过操作"
    fi
else
    echo "firewalld未运行，跳过端口开放操作"
fi


# 设置node_exporter版本
NODE_EXPORTER_VERSION="1.7.0"
# 创建一个下载目录
DOWNLOAD_DIR="/tmp/node_exporter"
mkdir -p "${DOWNLOAD_DIR}"
# 下载node_exporter
cd "${DOWNLOAD_DIR}"
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
# 解压缩文件
tar xvfz "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
# 移动node_exporter到/usr/local/bin
cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin
# 清理下载目录
rm -rf "${DOWNLOAD_DIR}"
# 创建node_exporter用户
useradd --no-create-home --shell /bin/false node_exporter
# 创建服务文件
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.netdev.address-info \
    --collector.filesystem.ignored-fs-types="^tmpfs$" \
    --collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc|)($$|/)"
[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd以读取新的node_exporter服务
sudo chmod 777 /usr/local/bin/node_exporter
ls -ld /usr/local/bin/node_exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
sudo systemctl status node_exporter


if systemctl is-active --quiet node_exporter; then
    echo "Node Exporter 安装成功并正在运行"
    # 获取IP地址（排除回环地址）
    # 发送飞书通知（包含主机名和IP）
    curl -X POST -H "Content-Type: application/json" \
         -d '{"msg_type":"text","content":{"text":"Node Exporter 成功","hostname":"'"$(hostname)"'","IP address":"'"$(hostname -I | awk '{print $1}')"'"}}' \
          https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe
else
    curl -X POST -H "Content-Type: application/json" \
         -d '{"msg_type":"text","content":{"text":"Node Exporter 失败","hostname":"'"$(hostname)"'","IP address":"'"$(hostname -I | awk '{print $1}')"'"}}' \
          https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe
    echo "Node Exporter 安装失败"
fi
