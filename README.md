# 芽伴 · Sprout

为长时间坐在屏幕前的人设计的原生 macOS 健康桌宠。SwiftUI + AppKit，零第三方运行时依赖。

## 下载与自动打包

**直接安装：打开 [Releases](https://github.com/hblovo/sprout-desktop/releases/latest)，在 Assets 中下载对应芯片的 DMG。无需登录 GitHub。**

发布新版时先更新 `Info.plist` 中的版本号，再推送对应的 `v版本号` 标签；也可在 Actions → Package macOS → Run workflow 勾选 `Publish version from Info.plist to Releases`。两种架构构建及校验都成功后，自动上传 DMG、ZIP 和校验文件，再公开 Release。已发布的版本不会自动覆盖；新版需使用新的版本号。

仓库的 **Actions → Package macOS** 会在 `main` 更新时自动运行，也可以点击 **Run workflow** 手动启动。每次先运行回归测试，再分别生成 Apple Silicon（`arm64`）和 Intel（`x86_64`）安装包。

打开成功的运行记录，在 **Artifacts** 中下载对应的 `Sprout-macos-arm64` 或 `Sprout-macos-x86_64`。解压后包含 `.dmg`、应用 `.zip` 和 SHA-256 校验文件；打开 DMG 后将「芽伴」拖入 Applications 即可。构建产物保留 14 天，过期可重新运行。

自动打包使用本地开发签名，不需要上传 Apple 凭证；尚未进行 Developer ID 签名和公证。

## 运行

- macOS 14 或更新版本。
- 按处理器选择 Apple Silicon 或 Intel 安装包；本地直接构建时使用当前 Mac 的处理器架构。
- 打开 `dist/芽伴.app` 即可，也可以把它拖入「应用程序」。
- 关闭主窗口后，菜单栏和桌宠继续运行。`⌘Q` 完全退出，`⌘,` 打开设置。
- 这是本地开发签名版本，尚未进行 Apple Developer ID 签名和公证；正式分发前需完成签名、公证和发行环境验证。

## 使用

- **起身提醒**：默认专注 45 分钟、休息 2 分钟；可自行调整。到点显示桌宠气泡，可以开始休息或延后 5 分钟。
- **智能感知离开**：仅读取系统返回的「距上次键鼠／触控输入的秒数」。闲置达到 60 秒，暂停专注计时；闲置 2–30 分钟后返回，询问是否起身，确认才计入活动。离开超过 30 分钟仍保留原来的剩余时间，不增加活动次数。阅读、看视频也可能触发闲置，可在设置关闭。
- **主动休息**：倒计时期间可暂停、继续或取消。结束后确认「活动过了」才保存；选择没有活动，则恢复休息前剩余的专注时间。软件不判断姿势，也不会将无人操作直接当成站立。
- **不回应也没关系**：返回后的确认提示在活跃使用电脑 60 秒后自动关闭，不增加记录，并继续原来的计时。
- **睡眠／锁屏**：通过 NSWorkspace 的睡眠、显示器睡眠和会话状态事件暂停；各状态分别恢复后才继续。不会补发休眠期间的提醒。
- **计时持久化**：剩余时间、暂停、稍后提醒、休息进度和待确认活动自动保存。正常退出、关闭主窗口和状态切换立即保存；运行中每约 5 秒检查点保存。重启后接着走，不扣除应用退出期间的时间；强制终止最多损失约一个检查点间隔。修改饮水容量等无关设置不会重置计时。确认完成休息或主动修改专注间隔才开始新一轮。
- **喝水打卡**：默认每杯 250 mL、每日目标 2000 mL；均可按个人需要修改。支持撤销最近一杯、撤销单条记录、近七日趋势和 JSON 导出。目标只是个人习惯设置。
- **桌宠**：拖动移动；点击打开主面板；悬停显示喝水、暂停、隐藏；右键显示菜单。位置保存在本机，屏幕变化时重新限制到可见区域。
- **提醒方式**：默认使用桌宠，不主动弹出权限申请。可在设置中启用静音系统通知；按需开启每 60 分钟喝水提醒和安静时段。

## 数据

记录与偏好存放在 `~/Library/Application Support/Sprout/health.json`；小型计时检查点独立存放在同目录的 `health.session.json`，分别以原子方式写入，避免高频重写历史。按当前系统日历／时区统计每天的数据，跨天不删除历史。活动确认有稳定 ID，避免在保存中断后重复计数。

没有服务器、账户、遥测、摄像头、录音、屏幕采集或键盘内容采集。系统通知是本地通知。检测到不兼容或损坏的记录时停止覆盖原文件，并在界面中提示；当次记录可通过导出功能另存。

## 开发

需要 Swift 6.0+ 工具链和 macOS SDK。当前在 macOS 15.7.9、Apple Silicon、Swift 6.1.2 上构建和验证。

```bash
# 构建 Release 应用和原生图标，执行本地 ad-hoc 签名
bash scripts/build.sh

# 构建应用，并生成带 Applications 快捷方式的 DMG、ZIP 与校验文件
bash scripts/package.sh

# 单元和应用状态测试
bash scripts/test.sh

# 开发构建
bash scripts/build.sh debug

# 使用内存中的示例数据预览，不修改个人记录
open -n dist/芽伴.app --args --demo

# 预览到点提醒（只在 demo 模式有效）
open -n dist/芽伴.app --args --demo --preview-due

# 从真实 SwiftUI 视图生成示例界面图片，不截取用户桌面
dist/芽伴.app/Contents/MacOS/Sprout --render-preview /tmp/sprout-preview
```

`Sources/SproutCore` 负责计时状态、闲置判断、日期统计和文件持久化；`Sources/SproutApp` 负责主界面、桌宠、菜单栏、系统事件和通知。

40 项测试覆盖提醒只触发一次、延后、暂停、休息完成待确认、重复确认防重、拒绝后恢复原计时、关闭闲置检测、锁屏与睡眠的组合状态、跨午夜、夏令时、饮水撤销、旧偏好兼容、损坏文件保护，以及普通计时／暂停／延后／进行中的休息／待确认活动的重启恢复。

系统接口参考：[Apple 的输入闲置时长接口](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:))、[本地通知授权](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)。
