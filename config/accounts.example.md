# 多账号配置示例

## GitHub Secrets 配置说明

### 必需配置
- `BARK_URL`: Bark 服务器地址（如：`https://api.day.app`）
- `BARK_KEY`: Bark 设备 Key

### 账号配置（最多支持5个账号）

#### 账号1（必需）
- `ACCOUNT1_COOKIE`: 第一个账号的 Cookie
- `ACCOUNT1_NAME`: 第一个账号的名称（如：`主账号`）

#### 账号2（可选）
- `ACCOUNT2_COOKIE`: 第二个账号的 Cookie
- `ACCOUNT2_NAME`: 第二个账号的名称（如：`备用账号`）

#### 账号3（可选）
- `ACCOUNT3_COOKIE`: 第三个账号的 Cookie
- `ACCOUNT3_NAME`: 第三个账号的名称（如：`测试账号`）

#### 账号4（可选）
- `ACCOUNT4_COOKIE`: 第四个账号的 Cookie
- `ACCOUNT4_NAME`: 第四个账号的名称（如：`朋友账号`）

#### 账号5（可选）
- `ACCOUNT5_COOKIE`: 第五个账号的 Cookie
- `ACCOUNT5_NAME`: 第五个账号的名称（如：`家庭账号`）

## 配置步骤

1. 进入 GitHub 仓库
2. 点击 Settings → Secrets and variables → Actions
3. 点击 "New repository secret" 添加每个配置项
4. 按照上表填写 Secret 名称和值

## 注意事项

- 账号名称用于区分不同账号，建议使用有意义的名称
- 如果某个账号的 Cookie 或名称未设置，该账号将被跳过
- 账号间会有30秒的延迟，避免请求过于频繁
- 所有账号的签到结果都会推送到同一个 Bark 设备

## 单账号模式

如果只配置了 `GLADOS_COOKIE`（不配置多账号），系统将自动使用单账号模式，保持向后兼容。
