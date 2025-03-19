#!/bin/bash
# 添加跳板机
if ! id -g dev >/dev/null 2>&1
then
  groupadd -g 10000 dev
fi
if ! id -g ops >/dev/null 2>&1
then
  groupadd -g 9999 ops
fi
if ! id -g deploy >/dev/null 2>&1
then
  groupadd -g 9998 deploy
fi
if ! id -u dev >/dev/null 2>&1
then
  useradd -u 10000 -g 10000 -s /bin/bash -c DEV dev -d /home/dev
  mkdir -p /home/dev/.ssh
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDysEMU5maFhG30jOzkGnUGtmfs1wI1d4VlExy5UQHWvn5n412y1uaZX64aAxZiXn1Bwhgjxe1WKVLdlhMjcthQpo2PAj+1OJa8P0wQAVh0uWWvbqLVNCZUN9NLfIT/6OJTgDfGNHMWXgruEHnekNwTRGJsCOTONgsH9OLil3QQ1e5GNnTEAe76f8AbJ5UOR1u/B935bvRw2rB+r3Mwxm35ooHYKRh5yqqmrzLBahf3HLloX5O7UkkPLglzEC8/EtgGnNgCqYyaFZ6fYqiHKG72Ltyp/2Vdcw/zmAT43RnIdqSbvU98eRI/vq6ae5OFfJrKhZ+RG0545ocRbzw3QEvr jumpserver@localhost" >> /home/dev/.ssh/authorized_keys
  chmod 600 /home/dev/.ssh/authorized_keys
  chown -R dev:dev /home/dev
fi
if ! id -u ops >/dev/null 2>&1
then
  useradd -u 9999 -g 9999 -s /bin/bash -c OPS ops -d /home/ops
  mkdir -p /home/ops/.ssh
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDfYyMb5n54xxWyZGtU+o/B9OHUyaKqld8+mYZLdgxy7aOTZ0Rpf0mWurj5jyYbOWBpKOJ8g0cTmUjbrT+1yGtikgj3vmO0my4mh7AKAyQmQWJXhWHpf1wkhQLHGT7HlMgdysY3K44u5JNE3dRfLCj10AN7I/i8PD8B/ykwF+Ws5wK91dIUVkNKqULEsxGNc+ZpFzhVyDZAch69AOQBagob9l8O5mo6PuS7nJd1dFwqgbXewXcSDEsP8Kq16+BNmKXNSfWDwgIYGu1aMkp9Xfyti4MJNbapsuRlu9eRJoNrTE+msiI8jLTjmGCBlmCr/U9sGo4dsyJBo65sz6YCJUi7 jumpserver@localhost" >> /home/ops/.ssh/authorized_keys
  chmod 600 /home/ops/.ssh/authorized_keys
  chown -R ops:ops /home/ops
fi
if ! id -u deploy >/dev/null 2>&1
then
  useradd -u 9998 -g 9998 -s /bin/bash -c DEPLOY deploy -d /home/deploy
  mkdir -p /home/deploy/.ssh
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD347BIedavhAjFdLxH776/NNY62URG9tbfpsKjjhyrhy4e/L1UmlhS0CgWWzUjzhV3Sm9TWq6kxIjxeGUS1FyIbMFm1A/9V6bW7tmMOTn7QT8W2ytwm7pWkWSzL3yPNCZiHUJU/hHq5G6r+KaKZkejHhpJYTO9GRxL4AmshelvOVGjv18NYCK2RTaFCTrhVu/4nkOBvLZeTvdwM/tIQnWNStE6JG2gy/B7xlUGWkeuirhN0/HclTyEX+3zk/q2KvirG3+Pmf2pyYnMK/VOeJKged78GGVGdF31ZuHphp6swHMairtIquaG1QQPzpGLaIPvS+DBPKUNV17eRWsdw551 deploy@allhost" >> /home/deploy/.ssh/authorized_keys
  chmod 600 /home/deploy/.ssh/authorized_keys
  chown -R deploy:deploy /home/deploy
fi

echo "####Start Add sudoer file to ops user.####">> /tmp/osinit.log
  cat >/etc/sudoers.d/000-dianyi-ops<<EOF
# ops user.
# It needs passwordless sudo functionality.
ops ALL=(ALL) NOPASSWD:ALL
EOF


# 端口判断
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
          https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe
else
    curl -X POST -H "Content-Type: application/json" \
         -d '{"msg_type":"text","content":{"text":"Node Exporter 失败","hostname":"'"$(hostname)"'","IP address":"'"$(hostname -I | awk '{print $1}')"'"}}' \
          https://janzlz0n1f.feishu.cn/base/automation/webhook/event/PjcAa3QvHwokpMhUpsOcUQsCnKe
    echo "Node Exporter 安装失败"
fi
