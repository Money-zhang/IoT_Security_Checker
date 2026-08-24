# IoT Security Checker

一款用于 Linux 系统的 IoT 安全基线检查脚本

---

## 📌 项目简介

本项目是一个在 CentOS 环境下运行的 Shell 脚本，用于对 Linux 系统进行快速安全基线检查。它可以帮助运维和安全人员在 IoT 设备部署前，快速发现常见的安全配置问题。

---

## 🛠️ 检查功能

| 序号 | 检查项 | 说明 |
|------|--------|------|
| 1 | 端口开放检查 | 检查 21/22/23/80/443/1883/3306 等常见端口 |
| 2 | MQTT 安全评估 | 检查 1883（明文）和 8883（TLS）端口状态 |
| 3 | 默认账户检查 | 检查是否包含 pi/admin/root/user 等默认账户 |
| 4 | SSH 安全配置 | 检查是否允许 root 登录 |
| 5 | 高危服务检查 | 检查 telnet/ftp/rlogin/rexec 是否运行 |
| 6 | 登录失败日志 | 分析 /var/log/secure 中的认证失败记录 |
| 7 | 密码有效期审计 | 检查 root 用户密码最后修改时间 |

---

## 📊 输出示例

脚本运行后会生成两种格式的报告：

- **终端输出**：带颜色的实时结果(./images/terminal_output.png)
- **HTML 报告**：结构化表格展示(./images/html_report.png)
- **TXT 报告**：纯文本备份，便于存档(./images/txt_report.png)

---

## 🚀 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/IoT_Security_Checker.git
cd IoT_Security_Checker

# 2. 赋予执行权限
chmod +x iot_check.sh

# 3. 运行脚本
./iot_check.sh
