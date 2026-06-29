#!/bin/bash

set -e

# ========================
# 配置
# ========================
NODE_EXPORTER_VERSION="1.7.0"

# ========================
# 检查9100端口
# ========================
echo "⚠️  检查 9100 端口是否已经开放（精确匹配）"

if ss -tulnp | grep -q "LISTEN.*:9100"; then
    echo "端口 9100 已被监听，脚本终止"
    exit 0
fi

# ========================
# 检查firewalld
# ========================
echo "⚠️  检查 firewalld 是否正在运行"

if systemctl is-active --quiet firewalld; then
    if ! firewall-cmd --list-ports | grep -q "9100/tcp"; then
        firewall-cmd --add-port=9100/tcp --permanent
        firewall-cmd --reload
        echo "9100 端口已开放"
    else
        echo "端口9100已开放，跳过操作"
    fi
else
    echo "firewalld未运行，跳过端口开放操作"
fi

echo "⬇️ 开始安装 Node Exporter"

# ========================
# 自动识别架构
# ========================
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        NODE_ARCH="linux-amd64"
        ;;
    aarch64|arm64)
        NODE_ARCH="linux-arm64"
        ;;
    *)
        echo "❌ 不支持的CPU架构：$ARCH"
        exit 1
        ;;
esac

echo "检测到架构：$ARCH"
echo "下载版本：$NODE_ARCH"

# ========================
# 下载
# ========================
DOWNLOAD_DIR="/tmp/node_exporter"

rm -rf "${DOWNLOAD_DIR}"
mkdir -p "${DOWNLOAD_DIR}"

cd "${DOWNLOAD_DIR}"

wget \
"https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_ARCH}.tar.gz"

# ========================
# 解压
# ========================
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.${NODE_ARCH}.tar.gz

# ========================
# 创建用户
# ========================
if ! id node_exporter >/dev/null 2>&1; then
    useradd --no-create-home --shell /bin/false node_exporter
fi

# ========================
# 安装
# ========================
cp node_exporter-${NODE_EXPORTER_VERSION}.${NODE_ARCH}/node_exporter /usr/local/bin/

chown node_exporter:node_exporter /usr/local/bin/node_exporter
chmod 755 /usr/local/bin/node_exporter

rm -rf "${DOWNLOAD_DIR}"

echo "⬆️ 创建 systemd 服务"

# ========================
# systemd
# ========================
cat >/etc/systemd/system/node_exporter.service <<EOF
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
    --collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc|)(\$|/)"

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "⚠️  启动服务"

systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter

echo
echo "==============================="
echo "状态检查"
echo "==============================="

if systemctl is-active --quiet node_exporter; then

    echo "✅ Node Exporter 安装成功并正在运行"

    systemctl --no-pager --full status node_exporter

    echo
    echo "监听端口："
    ss -lntp | grep 9100 || true

    echo
    echo "本地检测："
    curl -s http://127.0.0.1:9100/metrics | head

    curl -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "msg_type":"text",
            "content":{
                "text":"Node Exporter 成功",
                "hostname":"'"$(hostname)"'",
                "IP address":"'"$(hostname -I | awk "{print \$1}")"'"
            }
        }' \
https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe

else

    echo "❌ Node Exporter 安装失败"

    journalctl -u node_exporter -n 50 --no-pager

    curl -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "msg_type":"text",
            "content":{
                "text":"Node Exporter 失败",
                "hostname":"'"$(hostname)"'",
                "IP address":"'"$(hostname -I | awk "{print \$1}")"'"
            }
        }' \
https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe

    exit 1

fi
