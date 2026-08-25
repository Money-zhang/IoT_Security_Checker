# IoT Security Checker

物联网安全基线检查脚本，用于 Linux 系统（CentOS / RHEL 系列）的快速安全评估，帮助识别 IoT 网关及边缘设备的安全配置风险。

## 功能

脚本涵盖 8 类检查项，覆盖主机安全和 IoT 协议两个层面：

| 检查项 | 说明 |
|--------|------|
| 端口开放 | 检查 21/22/23/80/443/1883/3306 等常见端口 |
| MQTT 外网连通性 | 测试 1883（明文）和 8883（TLS）端口是否可达 |
| MQTT Broker 本地配置 | 检查 Mosquitto 的匿名访问、TLS、密码认证、ACL 配置 |
| 默认账户 | 检查是否存在 pi / admin / root / user 等默认账户 |
| SSH 配置 | 检查是否允许 root 登录 |
| 高危服务 | 检查 telnet / ftp / rlogin / rexec 是否在运行 |
| 登录日志 | 分析 /var/log/secure 中的失败登录记录 |
| 密码修改时间 | 检查 root 密码最后修改时间，识别长期未改密码的情况 |

## 输出

- 终端输出：带颜色的实时检查结果
- TXT 报告：纯文本格式，适合存档
- HTML 报告：表格化展示，适合面试和汇报展示

## 使用方法

```bash
git clone https://github.com/Money-zhang/IoT_Security_Checker.git
cd IoT_Security_Checker
chmod +x iot_check.sh
./iot_check.sh
