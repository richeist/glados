#!/bin/bash
# GLaDOS 自动签到脚本 - GitHub Actions 版本
# 支持 Bark 推送通知

# 配置参数
GLADOS_API_URL="https://glados.one/api/user/checkin"
BARK_API_URL="${BARK_URL}/push"

# 颜色输出函数
print_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

# 发送 Bark 推送通知
send_bark_notification() {
    local title="$1"
    local content="$2"
    local level="${3:-active}"  # active, timeSensitive, passive
    
    if [ -z "$BARK_URL" ] || [ -z "$BARK_KEY" ]; then
        print_warning "Bark 配置未设置，跳过推送通知"
        return 0
    fi
    
    local bark_data=$(cat <<EOF
{
    "title": "$title",
    "body": "$content",
    "device_key": "$BARK_KEY",
    "level": "$level",
    "badge": 1,
    "sound": "bell.caf"
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$bark_data" \
        "$BARK_API_URL")
    
    if echo "$response" | grep -q '"code":0'; then
        print_info "Bark 推送发送成功"
    else
        print_error "Bark 推送发送失败: $response"
    fi
}

# 执行签到
perform_checkin() {
    local cookie="$1"
    local account_name="${2:-默认账号}"
    
    print_info "开始执行 GLaDOS 签到 - 账号: $account_name"
    
    # 检查 Cookie 是否设置
    if [ -z "$cookie" ]; then
        print_error "账号 $account_name 的 Cookie 未设置"
        send_bark_notification "GLaDOS 签到失败" "账号 $account_name 的 Cookie 未配置" "timeSensitive"
        return 1
    fi
    
    # 执行签到请求
    local response=$(curl -s -b "$cookie" -d "token=glados.one" "$GLADOS_API_URL")
    
    # 记录 API 响应
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] API Response: $response" >> api.log
    
    # 解析签到结果
    local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    local code=$(echo "$response" | grep -o '"code":[0-9]*' | cut -d':' -f2)
    
    # 处理签到结果
    case "$message" in
        "Please Try Tomorrow")
            message="签到失败，请明天再试"
            print_warning "[$account_name] $message"
            send_bark_notification "GLaDOS 签到失败" "[$account_name] $message" "timeSensitive"
            ;;
        "Checkin! Get 1 Day")
            message="签到成功，有效期延长1天"
            print_info "[$account_name] $message"
            send_bark_notification "GLaDOS 签到成功" "[$account_name] $message" "active"
            ;;
        "Checkin! Get 0 day")
            message="签到成功，有效期没有延长"
            print_info "[$account_name] $message"
            send_bark_notification "GLaDOS 签到成功" "[$account_name] $message" "active"
            ;;
        *)
            message="签到结果未知: $message"
            print_warning "[$account_name] $message"
            send_bark_notification "GLaDOS 签到异常" "[$account_name] $message" "timeSensitive"
            ;;
    esac
    
    # 记录签到日志
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] $message"
    echo "$log_entry" >> sign.log
    echo "$log_entry" >> multi-account.log
    print_info "签到日志已记录: $log_entry"
    
    # 输出签到结果
    echo "$log_entry"
    
    # 返回签到是否成功
    if [[ "$message" == *"签到成功"* ]]; then
        return 0
    else
        return 1
    fi
}

# 获取账户信息（可选）
get_account_info() {
    local cookie="$1"
    local account_name="${2:-默认账号}"
    
    if [ -z "$cookie" ]; then
        return 0
    fi
    
    print_info "获取账户信息 - 账号: $account_name"
    local info_response=$(curl -s -b "$cookie" "https://glados.one/api/user/info")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$account_name] Account Info: $info_response" >> api.log
    
    # 解析剩余天数
    local left_days=$(echo "$info_response" | grep -o '"leftDays":[0-9]*' | cut -d':' -f2)
    if [ ! -z "$left_days" ]; then
        print_info "[$account_name] 账户剩余天数: $left_days 天"
        send_bark_notification "GLaDOS 账户状态" "[$account_name] 剩余天数: $left_days 天" "passive"
    fi
}

# 多账号签到函数
perform_multi_account_checkin() {
    print_info "开始执行多账号签到..."
    
    local total_accounts=0
    local success_count=0
    local fail_count=0
    
    # 检查并处理每个账号
    for i in {1..5}; do
        local cookie_var="ACCOUNT${i}_COOKIE"
        local name_var="ACCOUNT${i}_NAME"
        local cookie="${!cookie_var}"
        local name="${!name_var}"
        
        # 如果账号配置存在
        if [ ! -z "$cookie" ] && [ ! -z "$name" ]; then
            total_accounts=$((total_accounts + 1))
            print_info "处理账号 $i: $name"
            
            # 获取账户信息
            get_account_info "$cookie" "$name"
            
            # 执行签到
            if perform_checkin "$cookie" "$name"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
            
            # 账号间延迟，避免请求过于频繁
            if [ $i -lt 5 ]; then
                print_info "等待 30 秒后处理下一个账号..."
                sleep 30
            fi
        fi
    done
    
    # 输出总结
    print_info "多账号签到完成 - 总计: $total_accounts, 成功: $success_count, 失败: $fail_count"
    
    # 发送总结推送
    if [ $total_accounts -gt 0 ]; then
        local summary="多账号签到完成\n总计: $total_accounts 个账号\n成功: $success_count 个\n失败: $fail_count 个"
        send_bark_notification "GLaDOS 多账号签到总结" "$summary" "active"
    fi
}

# 单账号签到函数（兼容原有逻辑）
perform_single_checkin() {
    print_info "GLaDOS 单账号签到脚本启动"
    print_info "执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 获取环境变量
    local cookie="$GLADOS_COOKIE"
    
    # 获取账户信息
    get_account_info "$cookie"
    
    # 执行签到
    perform_checkin "$cookie"
    
    print_info "签到脚本执行完成"
}

# 主函数
main() {
    print_info "GLaDOS 自动签到脚本启动"
    print_info "执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 检查是否配置了多账号
    local has_multi_account=false
    for i in {1..5}; do
        local cookie_var="ACCOUNT${i}_COOKIE"
        local name_var="ACCOUNT${i}_NAME"
        if [ ! -z "${!cookie_var}" ] && [ ! -z "${!name_var}" ]; then
            has_multi_account=true
            break
        fi
    done
    
    if [ "$has_multi_account" = true ]; then
        print_info "检测到多账号配置，执行多账号签到"
        perform_multi_account_checkin
    else
        print_info "使用单账号模式"
        perform_single_checkin
    fi
}

# 执行主函数
main "$@"
