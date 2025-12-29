#!/bin/bash
set -euo pipefail

# 自动获取最新版本
VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
ARCH="linux-amd64"
FILE="node_exporter-${VERSION}.${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${FILE}"
INSTALL_DIR="/opt/node_exporter"

echo "=== 正在安装最新版 node_exporter v${VERSION} ==="

# 安装依赖
apt update -y
apt install -y wget curl

# 下载并校验
cd /tmp
echo "下载 $FILE ..."
wget -q "$URL"

# 可选 SHA256 校验（安全）
if wget -q "${URL}.sha256sum"; then
    echo "校验文件完整性..."
    sha256sum -c "${FILE}.sha256sum" || { echo "校验失败！"; exit 1; }
    rm "${FILE}.sha256sum"
else
    echo "警告：未找到 SHA256 文件，跳过校验"
fi

# 解压安装
echo "解压并安装..."
tar -xzf "$FILE"
rm -rf "$INSTALL_DIR"
mv "node_exporter-${VERSION}.${ARCH}" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/node_exporter"

# 创建 systemd 服务（用 root 运行）
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/node_exporter
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable --now node_exporter.service

# 清理临时文件
rm -f "/tmp/${FILE}"

echo "=== node_exporter v${VERSION} 安装完成！==="
echo "访问地址: http://$(curl -s ifconfig.me):9100/metrics"
echo "服务状态: $(systemctl is-active node_exporter.service)"
