# Phraso — 多语言口语学习 App（MVP）

> Understand → Assemble → Speak → Transfer → Review
> 帮助学习者理解语言结构、亲自组装句子并尽早开口，而不是先背一大堆孤立单词。

基于《Phraso 多语言学习 App MVP PRD v1.1》实现的 iPhone 优先 SwiftUI 应用。首发法语 / 西班牙语 / 德语 / 韩语，架构不写死语言数量——新增语言只需上线一个通过 QA 的 language pack JSON。

## 运行

1. 用 **Xcode 16+** 打开 `Phraso.xcodeproj`（项目使用文件系统同步分组，新增文件自动进 target）。
2. 选择 iPhone 模拟器直接运行。无需任何后端：游客模式、课程内容、复习、进度全部本机可用。
3. 测试订阅：在 Scheme → Options → StoreKit Configuration 中选择根目录的 `Phraso.storekit`，即可在付费墙购买 / 恢复 Phraso Plus（月度 `com.phraso.plus.monthly` / 年度 `com.phraso.plus.annual`）。

## 已实现的 P0 范围

| 领域 | 实现 |
|---|---|
| 游客学习 | 无需注册，引导后 60 秒内直接进入第一道构句练习 |
| 课程引擎 | 8–10 分钟课程：热身 → 理解 → 引导构句（先想后揭晓）→ 词块组装 → 开口 → 迁移 → 总结 |
| 练习判定 | 词块题按 token 序列比较（非字符串全等）；反馈标签：structure_correct / word_order / missing_required / pronunciation_attention / recognition_uncertain |
| 语音 | 能力分层：L0 参考音频+自评（无麦克风可完成课程）；L1 端侧 Speech 转写；权限只在首次点录音时申请，拒绝不阻塞课程 |
| 复习 | 掌握度驱动的间隔复习（1 → 3 → 7 → 14 天）；“掌握”必须来自无提示的迁移成功；识别不确定不降掌握度 |
| 多语言 | 每门语言独立的课程位置、复习队列与进度；两次点击切换语言 |
| 进度 | 展示“你能完成什么”：引擎掌握度、完成课程、本周有效学习；无连续打卡惩罚 |
| 订阅 | StoreKit 2；每门语言第 1 个引擎免费；付费墙含价格、周期、自动续期说明、恢复购买、条款/隐私链接；首课前绝不弹订阅 |
| 账户 | Sign in with Apple（可选，登录不阻塞学习）；App 内可发起删除账户/数据；单语言重置进度独立于删除账户 |
| 无障碍 | Dynamic Type 兼容布局、VoiceOver 标签、反馈用图标+文字（不只靠红绿）、录音状态有可见反馈 |

## 项目结构

```
Phraso/
├── App/            入口、主题（品牌色与控件样式）
├── Content/        语言包内容模型 + ContentStore（JSON 解码）
├── Models/         SwiftData 本地进度模型（语言/课程/掌握度/学习事件）
├── Services/       进度、复习调度、词块判定、音频、语音、StoreKit
├── Features/
│   ├── Onboarding/ 三步引导（价值→选语言→轻量目标，可跳过）
│   ├── Root/       四个一级 Tab（Learn / Review / Progress / Profile）
│   ├── Learn/      首页、语言切换器、句子引擎路径
│   ├── Lesson/     课程播放器与六类练习视图
│   ├── Review/     到期复习与快速复习会话
│   ├── Progress/   能力进度页
│   ├── Profile/    账户、订阅、隐私、危险操作
│   └── Paywall/    Phraso Plus 付费墙
└── Resources/
    └── Content/    fr / es / de / ko 语言包 JSON（每包 12 个引擎，前 4 个含完整课程）
```

## 内容说明

- 每个语言包定义 12 个句子引擎；引擎 1–4 已含完整可玩课程（原创内容，四语共享教学框架但**不共享机械翻译**：德语突出句框，韩语按助词/语尾/省略逻辑教学），引擎 5–12 为 `coming_soon` 占位，供内容团队按 PRD 16 的生产流程补齐至 48 节。
- 参考音频当前由 `AVSpeechSynthesizer` 生成，仅作开发占位。**发布前必须替换为母语者录音**（PRD 06 发布阻断项），`asset` 对象与清单机制已在内容 Schema 中预留。
- 韩语罗马字作为可关闭辅助（Profile 中切换）。

## 隐私边界（与代码行为一致）

- 原始录音只在本机内存中用于生成反馈，结束即丢弃；不落盘、不上传。
- 语音识别优先 `requiresOnDeviceRecognition`；不可用时降级为自评，不误判学习者。
- 学习事件只含聚合字段（课程 ID、时长），不含录音、答案全文或个人内容。

## 后续工作（PRD P1/P2）

- 云同步（最小 API / CloudKit 二选一后冻结）与登录合并策略
- 语言包 CDN 下发：签名 manifest、增量下载、版本回滚
- iPad 适配、更细发音反馈、学习目标与提醒
- 内容补齐至每语言 12 引擎 / 48 节课，接入母语审核与音频 QA 流程
