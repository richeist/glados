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
    
    print_info "开始执行 GLaDOS 签到..."
    
    # 检查 Cookie 是否设置
    if [ -z "$cookie" ]; then
        print_error "GLADOS_COOKIE 环境变量未设置"
        send_bark_notification "GLaDOS 签到失败" "Cookie 未配置，请检查 GitHub Secrets 设置" "timeSensitive"
        exit 1
    fi
    
    # 执行签到请求
    local response=$(curl -s -b "$cookie" -d "token=glados.one" "$GLADOS_API_URL")
    
    # 记录 API 响应
    echo "$(date '+%Y-%m-%d %H:%M:%S') - API Response: $response" >> api.log
    
    # 解析签到结果
    local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    local code=$(echo "$response" | grep -o '"code":[0-9]*' | cut -d':' -f2)
    
    # 处理签到结果
    case "$message" in
        "Please Try Tomorrow")
            message="签到失败，请明天再试"
            print_warning "$message"
            send_bark_notification "GLaDOS 签到失败" "$message" "timeSensitive"
            ;;
        "Checkin! Get 1 Day")
            message="签到成功，有效期延长1天"
            print_info "$message"
            send_bark_notification "GLaDOS 签到成功" "$message" "active"
            ;;
        "Checkin! Get 0 day")
            message="签到成功，有效期没有延长"
            print_info "$message"
            send_bark_notification "GLaDOS 签到成功" "$message" "active"
            ;;
        *)
            message="签到结果未知: $message"
            print_warning "$message"
            send_bark_notification "GLaDOS 签到异常" "$message" "timeSensitive"
            ;;
    esac
    
    # 记录签到日志
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - $message"
    echo "$log_entry" >> sign.log
    print_info "签到日志已记录: $log_entry"
    
    # 输出签到结果
    echo "$log_entry"
}

# 获取账户信息（可选）
get_account_info() {
    local cookie="$1"
    
    if [ -z "$cookie" ]; then
        return 0
    fi
    
    print_info "获取账户信息..."
    local info_response=$(curl -s -b "$cookie" "https://glados.one/api/user/info")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Account Info: $info_response" >> api.log
    
    # 解析剩余天数
    local left_days=$(echo "$info_response" | grep -o '"leftDays":[0-9]*' | cut -d':' -f2)
    if [ ! -z "$left_days" ]; then
        print_info "账户剩余天数: $left_days 天"
        send_bark_notification "GLaDOS 账户状态" "剩余天数: $left_days 天" "passive"
    fi
}

# 主函数
main() {
    print_info "GLaDOS 自动签到脚本启动"
    print_info "执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 获取环境变量
    local cookie="$GLADOS_COOKIE"
    
    # 获取账户信息
    get_account_info "$cookie"
    
    # 执行签到
    perform_checkin "$cookie"
    
    print_info "签到脚本执行完成"
}

# 执行主函数
main "$@"
