#!/bin/bash
# GLaDOS 自动签到脚本 - 新接口版本
# 支持 Bark 推送积分信息

# 配置参数
GLADOS_API_URL="https://glados.rocks/api/user/checkin"
BARK_API_URL="${BARK_URL}/push"

# ==================== 输出函数 ====================
print_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# ==================== Bark 推送 ====================
send_bark_notification() {
    local title="$1"
    local content="$2"
    local level="${3:-active}"      # active, timeSensitive, passive
    local group="${4:-GLaDOS}"      # 分组
    local icon="${5:-https://cdn-icons-png.flaticon.com/128/2763/2763437.png}"  # 默认图标

    if [ -z "$BARK_URL" ] || [ -z "$BARK_KEY" ]; then
        echo "[WARNING] Bark 配置未设置，跳过推送通知"
        return 0
    fi

    local bark_data=$(cat <<EOF
{
    "title": "$title",
    "body": "$content",
    "device_key": "$BARK_KEY",
    "level": "$level",
    "badge": 1,
    "sound": "bell.caf",
    "group": "$group",
    "icon": "$icon"
}
EOF
)

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$bark_data" \
        "$BARK_URL/push")

    if echo "$response" | grep -q '"code":0'; then
        echo "[INFO] Bark 推送发送成功"
    else
        echo "[ERROR] Bark 推送发送失败: $response"
    fi
}

# ==================== 执行签到 ====================
perform_checkin() {
    local cookie="$1"
    local account_name="${2:-默认账号}"
    
    print_info "开始签到 - 账号: $account_name"
    
    if [ -z "$cookie" ]; then
        print_error "账号 $account_name 的 Cookie 未设置"
        send_bark_notification "GLaDOS 签到失败" "账号 $account_name 的 Cookie 未配置" "timeSensitive"
        return 1
    fi
    
    local response=$(curl -s -b "$cookie" -X POST "$GLADOS_API_URL")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] API Response: $response" >> api.log
    
    # 解析响应
    local code=$(echo "$response" | grep -o '"code":[0-9]*' | cut -d':' -f2)
    local points=$(echo "$response" | grep -o '"points":[0-9]*' | cut -d':' -f2)
    local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$code" = "0" ]; then
        message="签到成功，获得积分: $points"
        print_info "[$account_name] $message"
        send_bark_notification "GLaDOS 签到成功" "[$account_name] $message" "active"
    else
        message="签到失败: $message"
        print_warning "[$account_name] $message"
        send_bark_notification "GLaDOS 签到失败" "[$account_name] $message" "timeSensitive"
    fi
    
    # 写入日志
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] $message"
    echo "$log_entry" >> sign.log
    echo "$log_entry" >> multi-account.log
    print_info "签到日志已记录: $log_entry"
    
    echo "$log_entry"
    
    [[ "$code" = "0" ]] && return 0 || return 1
}

# ==================== 获取账户信息 ====================
get_account_info() {
    local cookie="$1"
    local account_name="${2:-默认账号}"
    
    if [ -z "$cookie" ]; then return 0; fi
    
    print_info "获取账户信息 - 账号: $account_name"
    local info_response=$(curl -s -b "$cookie" "https://glados.rocks/api/user/info")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] Account Info: $info_response" >> api.log
    
    local points=$(echo "$info_response" | grep -o '"points":[0-9]*' | cut -d':' -f2)
    if [ ! -z "$points" ]; then
        print_info "[$account_name] 当前积分: $points"
        send_bark_notification "GLaDOS 账户积分" "[$account_name] 当前积分: $points" "passive"
    fi
}

# ==================== 多账号签到 ====================
perform_multi_account_checkin() {
    print_info "开始多账号签到..."
    
    local total=0
    local success=0
    local fail=0
    
    for i in {1..5}; do
        local cookie_var="ACCOUNT${i}_COOKIE"
        local name_var="ACCOUNT${i}_NAME"
        local cookie="${!cookie_var}"
        local name="${!name_var}"
        
        if [ ! -z "$cookie" ] && [ ! -z "$name" ]; then
            total=$((total+1))
            print_info "处理账号 $i: $name"
            
            get_account_info "$cookie" "$name"
            
            if perform_checkin "$cookie" "$name"; then
                success=$((success+1))
            else
                fail=$((fail+1))
            fi
            
            [ $i -lt 5 ] && print_info "等待30秒..." && sleep 30
        fi
    done
    
    print_info "多账号签到完成 - 总计: $total, 成功: $success, 失败: $fail"
    [ $total -gt 0 ] && send_bark_notification "GLaDOS 多账号签到总结" "总计: $total\n成功: $success\n失败: $fail" "active"
}

# ==================== 单账号签到 ====================
perform_single_checkin() {
    print_info "单账号签到模式"
    
    local cookie="$GLADOS_COOKIE"
    
    get_account_info "$cookie"
    perform_checkin "$cookie"
    
    print_info "签到脚本执行完成"
}

# ==================== 主函数 ====================
main() {
    print_info "GLaDOS 自动签到脚本启动 - $(date '+%Y-%m-%d %H:%M:%S')"
    
    local has_multi=false
    for i in {1..5}; do
        if [ ! -z "${!ACCOUNT${i}_COOKIE}" ] && [ ! -z "${!ACCOUNT${i}_NAME}" ]; then
            has_multi=true
            break
        fi
    done
    
    $has_multi && perform_multi_account_checkin || perform_single_checkin
}

main "$@"
