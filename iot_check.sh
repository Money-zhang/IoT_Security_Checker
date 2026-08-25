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
	if [[ $tls -eq 1 ]];then
		if [[ $plain -eq 0 ]];then
			print_result PASS "MQTT TLS 已启用（8883），明文端口1883已关闭（安全）"
		else
			print_result WARN "MQTT TLS 已启用（8883），但明文端口1883仍然开放，建议关闭明文"
		fi
	else
		if [[ $plain -eq 0 ]];then
			print_result FAIL "MQTT 服务不可用（1883和8883均不可连接）"
		else
			print_result WARN "MQTT 明文端口1883可连接，但TLS加密端口8883不可用，建议启用加密"
		fi
	fi
}

# 检查项2.1：MQTT Broker 本地配置（Mosquitto）
check_mqtt_config(){
	print_result INFO "检查MQTT Broker本地配置（Mosquitto）"
	local conf_file="/etc/mosquitto/mosquitto.conf"

	if [[ ! -f ${conf_file} ]];then
		print_result WARN "Mosquitto未安装或主配置文件不存在，跳过本地静态配置检查"
		return
	fi
	# 1. 匿名访问控制
	if grep -q "^allow_anonymous true" ${conf_file} 2>/dev/null;then
		print_result FAIL "MQTT配置允许匿名访问（高风险）"
	elif grep -q "^allow_anonymous false" ${conf_file} 2>/dev/null;then
		print_result PASS "MQTT匿名访问已禁用"
	else 
		print_result WARN "MQTT未显式定义allow_anonymous，旧版本默认允许匿名访问"
	fi

	# 2. TLS 加密配置
	local has_listener_8883=$(grep -c "^listener 8883" ${conf_file} 2>/dev/null)
	local has_ssl_cert=$(grep -E "^ssl_cafile|^ssl_certificate|^ssl_keyfile" ${conf_file} 2>/dev/null)
        if [[  ${has_listener_8883} -ge 1  && -n ${has_ssl_cert} ]];then
	        print_result PASS  "MQTT已配置TLS加密监听(8883)，包含证书配置"
        else
		print_result WARN "MQTT未完整配置TLS加密通信，明文传输存在数据劫持风险"
	fi

	# 3. 密码认证文件
	local password_file_path=$(grep "^password_file" ${conf_file} 2>/dev/null | awk '{print $2}')
	if [[ -n ${password_file_path} ]];then
		if [[ -s ${password_file_path} ]];then
			print_result PASS "MQTT已配置账号密码认证文件，且文件非空"
		else
			print_result FAIL "MQTT已配置password_file，但文件为空或不存在"
		fi
	else
		print_result WARN "MQTT未配置password_file，无独立账号认证机制"
	fi
	# 4. ACL Topic 访问控制
	if grep -q "^acl_file" ${conf_file} 2>/dev/null;then
		print_result PASS "MQTT已配置ACL主题访问控制列表"
	else
		print_result WARN "MQTT未配置ACL，设备间存在Topic越权订阅/发布风险"
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
        print_result INFO "检查SSH配置..."
        if [[ -f /etc/ssh/sshd_config ]];then
                if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null;then
                        print_result PASS "SSH已禁用root 登录"
                elif grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null;then
                        print_result FAIL "SSH允许root 登录（不安全）"
                else
                       print_result WARN "SSH未明确配置PermitRootLogin"
                fi
       else
               print_result WARN "SSH配置文件不存在"
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
                        print_result WARN "最近50条日志中有 $fail_count 条登录失败记>录"
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
    local timestamp=$(date +%Y%m%d_%H%M%S)
    report_file="iot_check_${timestamp}.txt"
    HTML_FILE="iot_check_${timestamp}.html"

    # ---- 生成 HTML 头部 ----
    cat > "$HTML_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>物联网安全基线检查报告</title>
<style>
body { font-family: Arial, sans-serif; margin: 40px; background-color: #f8f9fa; }
h1 { color: #333; }
.container { background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
th { background-color: #007bff; color: white; padding: 12px; text-align: left; }
td { padding: 10px; border: 1px solid #ddd; }
.pass { background-color: #d4edda; }
.fail { background-color: #f8d7da; }
.warn { background-color: #fff3cd; }
.summary { margin-top: 20px; padding: 15px; background-color: #e9ecef; border-radius: 6px; }
</style>
</head>
<body>
<div class="container">
<h1>🔒 物联网安全基线检查报告</h1>
<p><strong>检查时间：</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
<table>
<tr><th>状态</th><th>检查结果</th></tr>
EOF

    # ---- 执行所有检查 ----
    check_ports
    check_mqtt
    check_mqtt_config
    check_default_passwd
    check_ssh_config
    check_services
    check_logs
    check_passwd_aging

    # ---- 生成 HTML 尾部 ----
    cat >> "$HTML_FILE" << EOF
</table>
<div class="summary">
<strong>综合评分：</strong> ✅ PASS=$PASS  ❌ FAIL=$FAIL  ⚠️ WARN=$WARN
</div>
<p><small>报告文件：$report_file</small></p>
</div>
</body>
</html>
EOF

    # ---- 终端输出 ----
    echo "========================================" | tee -a "$report_file"
    echo "综合评分: PASS=$PASS  FAIL=$FAIL  WARN=$WARN" | tee -a "$report_file"
    echo "========================================" | tee -a "$report_file"
    echo "报告已保存至: $report_file"
    echo "HTML报告已保存至: $HTML_FILE"
}

# 执行
main
