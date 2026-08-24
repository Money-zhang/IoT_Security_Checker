#!/bin/bash

# =====================================================
# 物联网安全基线检查脚本
# 版本: 1.0
# 功能: 检查 6 项安全配置，生成报告
# =====================================================

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

# 变量定义
PASS=0
FAIL=0
WARN=0

# 函数：输出结果
print_result(){
        local status=$1
        local msg=$2
        case $status in
                PASS)   
                        echo -e "${GREEN}[PASS] ${NC}${msg}"
                        echo "[PASS] ${msg}" >> $report_file
			[[ -n "$HTML_FILE" ]] && echo "<tr style='background-color:#d4edda;'><td>[PASS]</td><td>${msg}</td></tr>" >> $HTML_FILE
                        ((PASS++))
                        ;;
                FAIL)
                        echo -e "${RED}[FAIL] ${NC}${msg}"
                        echo "[FAIL] ${msg}"  >> $report_file
                        ((FAIL++))
			[[ -n "$HTML_FILE" ]] && echo "<tr style='background-color:#f8d7da;'><td>[FAIL]</td><td>${msg}</td></tr>" >> $HTML_FILE
                        ;;
                WARN)
                        echo -e "${YELLOW}[WARN] ${NC}${msg}"
                        echo "[WARN] ${msg}" >> $report_file
                        ((WARN++))
			[[ -n "$HTML_FILE" ]] && echo "<tr style='background-color:#fff3cd;'><td>[WARN]</td><td>${msg}</td></tr>" >> $HTML_FILE
                        ;;
                *)
                        echo "[INFO] ${msg}"      
                        echo "[INFO] ${msg}" >> $report_file
                        ;;
        esac
}
# 检查项1：端口开放检查(21,22,23,443,80,1883,3306)
check_ports(){
        print_result INFO "开始检查开放端口..."
        local ports=(21 22 23 80 443 1883 3306)
        for port in "${ports[@]}";do
                if ss -tuln | grep -q ":$port ";then
                        if [[ $port -eq 21 ]] || [[ $port -eq 23 ]];then
                                print_result WARN "高危端口 $port 已开放"
                        else
                                print_result PASS "端口 $port 已开放"
                        fi
                else
                        print_result PASS "端口 $port 未开放（安全）"
                fi
        done
}

# 检查项2：MQTT 通信检查
check_mqtt(){
        print_result INFO "检查MQTT端口..."
	local plain=0
	local tls=0
        if timeout 2 mosquitto_pub -h broker.emqx.io -p 1883 -t "test/check" -m "test" &>/dev/null;then
		plain=1	
	fi
	if timeout 2 mosquitto_pub -h broker.emqx.io -p 8883 -t "test/check" -m "test" --insecure &>/dev/null;then
		tls=1
	fi
	if [[ tls -eq 1 ]];then
		if [[ plain -eq 0 ]];then
			print_result PASS "MQTT TLS 已启用（8883），明文端口1883已关闭（安全）"
		else
			print_result WARN "MQTT TLS 已启用（8883），但明文端口1883仍然开放，建议关闭明文"
		fi
	else
		if [[ plain -eq 0 ]];then
			print_result FAIL "MQTT 服务不可用（1883和8883均不可连接）"
		else
			print_result WARN "MQTT 明文端口1883可连接，但TLS加密端口8883不可用，建议启用加密"
		fi
	fi
}

# 检查项3：默认密码检查
check_default_passwd(){
        print_result INFO "检查默认账户..."
        local users=("pi" "admin" "root" "user")
        local found=0
        for user in "${users[@]}";do
                if grep -q "^${user}:" /etc/passwd 2>/dev/null;then
                        print_result WARN "默认账户 ${user} 存在"
                        found=1
                fi
        done
        if [[ $found -eq 0 ]];then
               print_result PASS "未发现默认账户"
       fi
}
# 检查项4：SSH 配置检查
check_ssh_config(){
        print_result INFO "检查 SSH 配置..."
        if [[ -f /etc/ssh/sshd_config ]];then
                if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null;then
                        print_result PASS "SSH 已禁用 root 登录"
                elif grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null;then
                        print_result FAIL "SSH 允许 root 登录（不安全）"
                else
                       print_result WARN "SSH 未明确配置 PermitRootLogin"
                fi
       else
               print_result WARN "SSH 配置文件不存在"
       fi

}

# 检查项5：高危服务检查
check_services(){
        print_result INFO "检查高危服务..."
        local services=("telnet" "ftp" "rlogin" "rexec")
        for service in "${services[@]}";do
                if systemctl is-active --quiet $service 2>/dev/null;then
                                print_result WARN "高危服务 ${service} 正在运行"
                else
                        print_result PASS "高危服务 ${service} 未运行"
                fi
        done

}

# 检查项6：日志检查
check_logs(){
        print_result INFO "检查登录失败记录..."
        local log_file="/var/log/secure"
        if [[ -f $log_file ]];then
                local fail_count=$(tail -50 $log_file 2>/dev/null | grep -c "Failed password")
                if [[ $fail_count -gt 3 ]];then
                        print_result WARN "最近 50 条日志中有 $fail_count 条登录失败记>录"
                else
                        print_result PASS "登录失败记录正常 ($fail_count 条)"
                fi
        else
                print_result WARN "日志文件 $log_file 不存在"
        fi
}

# 检查项7：密码修改时间检查
check_passwd_aging(){
	print_result INFO "检查密码修改时间..."
	if [[ -f /etc/shadow ]];then
		 # 提取root的密码最后修改时间
		local last_change=$(grep "^root:" /etc/shadow | cut -d: -f3)
		if [[ -n "${last_change}" && ${last_change} -gt 0 ]];then
			# 计算上次修改距今的天数
			local now_time=$(date +%s)
		        local last_change_seconds=$((last_change * 86400))
		        local day_ago=$(( (now_time - last_change_seconds) / 86400 ))
			print_result PASS "root密码已修改（距离上次修改约 $day_ago 天）"
		else
			print_result FAIL "root密码从未修改"
		fi
	else
		print_result WARN "shadow文件不存在"
	fi

}
# 主函数
main(){
    # 设置报告文件名
    local timestamp=$(date +%Y%m%d_%H%M%S)
    report_file="iot_check_${timestamp}.txt"
    HTML_FILE="iot_check_${timestamp}.html"

    # 写入 HTML 头部
    cat > $HTML_FILE << EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>物联网安全基线检查报告</title>
<style>
body { font-family: Arial, sans-serif; margin: 40px; }
h1 { color: #333; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
th { background-color: #007bff; color: white; padding: 10px; text-align: left; }
td { padding: 8px; border: 1px solid #ddd; }
tr:nth-child(even) { background-color: #f2f2f2; }
.pass { background-color: #d4edda; }
.fail { background-color: #f8d7da; }
.warn { background-color: #fff3cd; }
.info { background-color: #d1ecf1; }
</style>
</head>
<body>
<h1>🔒 物联网安全基线检查报告</h1>
<p><strong>检查时间：</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
<table>
<tr><th>状态</th><th>检查结果</th></tr>
EOF

    # 执行所有检查
    check_ports
    check_mqtt
    check_default_passwd
    check_ssh_config
    check_services
    check_logs
    check_passwd_aging

    # 写入 HTML 尾部
    cat >> $HTML_FILE << EOF
</table>
<p><strong>综合评分：</strong> PASS=$PASS  FAIL=$FAIL  WARN=$WARN</p>
<p><strong>报告文件：</strong> $report_file</p>
</body>
</html>
EOF

    # 终端输出总结
    echo "========================================" | tee -a $report_file
    echo "综合评分: PASS=$PASS  FAIL=$FAIL  WARN=$WARN" | tee -a $report_file
    echo "========================================" | tee -a $report_file
    echo "报告已保存至: $report_file"
    echo "HTML报告已保存至: $HTML_FILE"
}
main
