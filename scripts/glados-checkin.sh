#!/usr/bin/env bash
set -eo pipefail

# ==================== 配置 ====================
GLADOS_API_URL="${GLADOS_API_URL:-https://glados.rocks/api/user/checkin}"
GLADOS_INFO_URL="${GLADOS_INFO_URL:-https://glados.rocks/api/user/info}"

DEFAULT_BARK_GROUP="${DEFAULT_BARK_GROUP:-GLaDOS}"
DEFAULT_BARK_ICON="${DEFAULT_BARK_ICON:-https://cdn-icons-png.flaticon.com/128/2763/2763437.png}"

# ==================== 输出 ====================
print_info()  { echo -e "\033[32m[INFO]\033[0m $*"; }
print_warn()  { echo -e "\033[33m[WARNING]\033[0m $*"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $*"; }

# ==================== 时间（北京时间） ====================
beijing_time() {
  if date --version >/dev/null 2>&1; then
    date -u -d '+8 hour' '+%Y-%m-%d %H:%M:%S'
  else
    TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'
  fi
}

# ==================== JSON 解析 ====================
json_get() {
  local _json="$1"; local _path="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$_json" | jq -r "$_path" 2>/dev/null || echo ""
  else
    case "$_path" in
      '.code')   echo "$_json" | grep -o '"code":[0-9]*' | cut -d: -f2 || echo "" ;;
      '.points') echo "$_json" | grep -o '"points":[0-9]*' | cut -d: -f2 || echo "" ;;
      '.message') echo "$_json" | grep -o '"message":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "" ;;
      '.data.leftDays') echo "$_json" | grep -o '"leftDays":[0-9]\+\.?[0-9]*' | cut -d: -f2 || echo "" ;;
      *) echo "" ;;
    esac
  fi
}

# ==================== 推送函数 ====================
send_bark_notification() {
  local title="$1" body="$2"
  if [ -z "$BARK_URL" ] || [ -z "$BARK_KEY" ]; then return 0; fi

  curl -s -X POST -H "Content-Type: application/json" -d "{
    \"title\": \"$title\",
    \"body\": \"$body\",
    \"device_key\": \"$BARK_KEY\",
    \"level\": \"active\",
    \"group\": \"$DEFAULT_BARK_GROUP\",
    \"icon\": \"$DEFAULT_BARK_ICON\"
  }" "$BARK_URL/push" >/dev/null 2>&1
}

send_telegram_notification() {
  local title="$1" body="$2"
  if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then return 0; fi
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TG_CHAT_ID" \
    -d parse_mode="HTML" \
    -d text="🕒 $(beijing_time)\n<b>$title</b>\n\n$body" >/dev/null 2>&1
}

# ==================== 签到逻辑 ====================
perform_checkin() {
  local cookie="$1" name="$2"
  if [ -z "$cookie" ]; then
    echo "$(beijing_time) - [$name] Cookie 未设置" >> multi-account.log
    return 1
  fi

  local resp code points message
  resp=$(curl -s -b "$cookie" -H "Content-Type: application/json" -d '{"token":"glados.one"}' -X POST "$GLADOS_API_URL")
  echo "$(beijing_time) - [$name] CHECKIN: $resp" >> api.log

  code=$(json_get "$resp" '.code')
  points=$(json_get "$resp" '.points')
  message=$(json_get "$resp" '.message')

  if [ "$code" = "0" ]; then
    echo "$(beijing_time) - [$name] 签到成功，获得积分: ${points:-0}" >> sign.log
    echo "✅ $name 签到成功 (+${points:-0})"
    return 0
  else
    echo "$(beijing_time) - [$name] 签到失败: ${message:-未知错误}" >> sign.log
    echo "❌ $name 签到失败 (${message:-未知错误})"
    return 1
  fi
}

# ==================== 多账号执行 ====================
main() {
  local total=0 success=0 fail=0 results=""

  for i in 1 2 3 4 5; do
    cookie_var="ACCOUNT${i}_COOKIE"
    name_var="ACCOUNT${i}_NAME"
    cookie="${!cookie_var}"
    name="${!name_var}"

    if [ -n "$cookie" ] && [ -n "$name" ]; then
      total=$((total+1))
      result=$(perform_checkin "$cookie" "$name") || true
      if echo "$result" | grep -q "✅"; then
        success=$((success+1))
      else
        fail=$((fail+1))
      fi
      results="${results}\n${result}"
      sleep 2
    fi
  done

  if [ $total -eq 0 ]; then
    print_warn "没有检测到账号"
    exit 1
  fi

  local summary="GLaDOS 签到完成\n总计: $total 个账号\n成功: $success, 失败: $fail\n$results"
  echo "$summary" >> multi-account.log

  # ✅ 统一推送一次
  send_bark_notification "GLaDOS 多账号签到总结" "$summary"
  send_telegram_notification "GLaDOS 多账号签到总结" "$summary"

  print_info "$summary"
}

main "$@"
