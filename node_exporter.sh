#!/bin/bash
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
systemctl daemon-reload
# 启用node_exporter服务
systemctl enable node_exporter
# 启动node_exporter服务
systemctl start node_exporter
if systemctl is-active --quiet node_exporter; then
    echo "Node Exporter 安装成功并正在运行"
    # 获取IP地址（排除回环地址）
    # 发送飞书通知（包含主机名和IP）
    curl -X POST -H "Content-Type: application/json" \
         -d '{"msg_type":"text","content":{"text":"Node Exporter 成功","hostname":"'"$(hostname)"'","IP address":"'"$(hostname -I | awk '{print $1}')"'"}}' \
          https://open.feishu.cn/open-apis/bot/v2/hook/42366247-c6a4-4f28-8d4f-97e8f415dd5c
else
    curl -X POST -H "Content-Type: application/json" \
         -d '{"msg_type":"text","content":{"text":"Node Exporter 失败","hostname":"'"$(hostname)"'","IP address":"'"$(hostname -I | awk '{print $1}')"'"}}' \
          https://open.feishu.cn/open-apis/bot/v2/hook/42366247-c6a4-4f28-8d4f-97e8f415dd5c
    echo "Node Exporter 安装失败"
fi