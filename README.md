# GLaDOS 多账号自动签到系统

基于 GitHub Actions 的 GLaDOS 自动签到解决方案，支持多账号管理和 Bark 推送通知。

## 🚀 功能特性

- ✅ **多账号支持**：最多支持5个账号同时签到
- 📱 **Bark 推送**：签到结果实时推送到手机
- 🔒 **安全存储**：Cookie 等敏感信息通过 GitHub Secrets 安全存储
- 📊 **日志记录**：完整的签到日志和 API 响应记录
- 🎯 **随机时间**：避免固定时间签到，更加自然
- 🔄 **手动触发**：支持手动执行签到任务
- 🔄 **向后兼容**：支持单账号模式，保持原有功能
- ⏱️ **智能延迟**：账号间自动延迟，避免请求过于频繁

## 📋 配置步骤

### 1. 获取 GLaDOS Cookie

1. 登录 [GLaDOS](https://glados.one)
2. 打开浏览器开发者工具 (F12)
3. 进入 Network 标签页
4. 刷新页面或执行一次签到
5. 找到对 `glados.one` 的请求
6. 复制请求头中的 `Cookie` 值

### 2. 配置 Bark 推送（可选）

1. 下载并安装 [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) 应用
2. 在应用中获取设备 Key
3. 记录 Bark 服务器地址（如：`https://api.day.app`）

### 3. 设置 GitHub Secrets

#### 多账号模式（推荐）

在 GitHub 仓库中设置以下 Secrets：

| Secret 名称 | 描述 | 示例 |
|------------|------|------|
| `BARK_URL` | Bark 服务器地址 | `https://api.day.app` |
| `BARK_KEY` | Bark 设备 Key | `your-device-key` |
| `ACCOUNT1_COOKIE` | 第一个账号的 Cookie | `koa:sess=eyJ...` |
| `ACCOUNT1_NAME` | 第一个账号名称 | `主账号` |
| `ACCOUNT2_COOKIE` | 第二个账号的 Cookie（可选） | `koa:sess=eyJ...` |
| `ACCOUNT2_NAME` | 第二个账号名称（可选） | `备用账号` |
| `ACCOUNT3_COOKIE` | 第三个账号的 Cookie（可选） | `koa:sess=eyJ...` |
| `ACCOUNT3_NAME` | 第三个账号名称（可选） | `测试账号` |
| `ACCOUNT4_COOKIE` | 第四个账号的 Cookie（可选） | `koa:sess=eyJ...` |
| `ACCOUNT4_NAME` | 第四个账号名称（可选） | `朋友账号` |
| `ACCOUNT5_COOKIE` | 第五个账号的 Cookie（可选） | `koa:sess=eyJ...` |
| `ACCOUNT5_NAME` | 第五个账号名称（可选） | `家庭账号` |

#### 单账号模式（向后兼容）

如果只想使用单账号，可以只设置：

| Secret 名称 | 描述 | 示例 |
|------------|------|------|
| `GLADOS_COOKIE` | GLaDOS 网站的 Cookie | `koa:sess=eyJ...` |
| `BARK_URL` | Bark 服务器地址 | `https://api.day.app` |
| `BARK_KEY` | Bark 设备 Key | `your-device-key` |

### 4. 启用 GitHub Actions

1. 将代码推送到 GitHub 仓库
2. 进入仓库的 Actions 标签页
3. 启用 GitHub Actions（如果未启用）

## 🔧 使用方法

### 自动执行
- 脚本会在每天北京时间 8:00-10:00 之间随机执行
- 无需手动干预，完全自动化

### 手动执行
1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "GLaDOS 自动签到" 工作流
3. 点击 "Run workflow" 按钮
4. 选择分支并点击 "Run workflow"

## 📁 项目结构

```
glsfod/
├── .github/
│   └── workflows/
│       └── glados-checkin.yml    # GitHub Actions 工作流
├── scripts/
│   └── glados-checkin.sh         # 签到脚本
└── README.md                     # 项目说明
```

## 📊 日志文件

执行完成后会生成以下日志文件：

- `api.log`：API 请求和响应记录
- `sign.log`：签到结果记录
- `multi-account.log`：多账号签到详细日志（仅多账号模式）

这些日志文件会作为 GitHub Actions 的 Artifacts 保存，可在 Actions 页面下载。

## 🔄 多账号管理

### 账号配置说明

- **最多支持5个账号**：通过 `ACCOUNT1_COOKIE` 到 `ACCOUNT5_COOKIE` 配置
- **账号名称**：通过 `ACCOUNT1_NAME` 到 `ACCOUNT5_NAME` 设置，用于区分不同账号
- **智能跳过**：未配置的账号会自动跳过
- **延迟机制**：账号间有30秒延迟，避免请求过于频繁

### 推送通知说明

- **单账号推送**：每个账号的签到结果都会单独推送
- **总结推送**：多账号签到完成后会发送总结推送
- **账号标识**：所有推送都会包含账号名称，便于区分

## 🔔 推送通知说明

### 通知类型

- **签到成功**：绿色通知，包含延长天数信息
- **签到失败**：红色通知，包含失败原因
- **账户状态**：蓝色通知，显示剩余天数

### 通知级别

- `active`：签到成功通知，会立即显示
- `timeSensitive`：签到失败通知，高优先级
- `passive`：账户状态通知，静默推送

## ⚠️ 注意事项

1. **Cookie 有效期**：GLaDOS Cookie 可能会过期，需要定期更新
2. **网络环境**：GitHub Actions 运行在海外，确保网络连接正常
3. **推送限制**：Bark 免费版有推送频率限制，请合理使用
4. **隐私安全**：不要将 Cookie 等敏感信息提交到代码仓库

## 🛠️ 故障排除

### 常见问题

1. **签到失败**
   - 检查 Cookie 是否有效
   - 查看 Actions 日志了解具体错误

2. **推送不成功**
   - 验证 Bark URL 和 Key 是否正确
   - 检查 Bark 应用是否正常运行

3. **定时任务不执行**
   - 确认 GitHub Actions 已启用
   - 检查仓库是否设置为公开（免费版限制）

### 调试方法

1. 查看 GitHub Actions 执行日志
2. 下载 Artifacts 中的日志文件
3. 手动触发工作流进行测试

## 📄 许可证

本项目仅供学习和个人使用，请遵守 GLaDOS 服务条款。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！
