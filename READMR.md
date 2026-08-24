# IoT Security Baseline Checker

一款用于 Linux 系统（CentOS）的 IoT 安全基线检查脚本。

## 🔍 主要功能
- 端口开放检查 (21, 22, 23, 80, 443, 1883, 3306)
- MQTT 服务安全评估 (1883 明文 / 8883 TLS)
- 系统账户与 SSH 安全基线
- 高危服务检测 (telnet, ftp 等)
- 登录失败日志分析
- 密码更新策略审计

## 📊 输出示例
- **终端彩色输出**：实时显示检查过程
- **HTML 报告**：结构化表格展示，便于存档和分享
- **TXT 报告**：纯文本格式，便于其他工具处理

## 🛠️ 环境要求
- CentOS / RHEL 7+
- bash, grep, awk, sed, systemctl
- mosquitto_pub (用于 MQTT 测试)

## 🚀 快速开始
```bash
# 克隆或下载项目后
chmod +x iot_check.sh
./iot_check.sh
