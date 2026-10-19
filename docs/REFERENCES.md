# 参考与借鉴

这一版（v0.7）在设计时参考了线上 AI 陪伴类产品、角色卡生态和 Flutter 官方文档。
下面记录“看了什么”和“用在了哪里”，方便后续继续迭代。

## 角色卡生态

- **Character Card V2 规范**（SillyTavern 生态）
  <https://github.com/malfoyslastname/character-card-spec-v2>
  - 借鉴点：`name / description / personality / scenario / first_mes / mes_example / tags / creator / character_version / extensions` 这套字段；
  - 用在：`data/personas.dart` 的导出/导入，导出时同时写 `spec: chara_card_v2` 和本应用的 `extensions.aining`。
- **character-cards-v2 数据示例**
  <https://github.com/bradennapier/character-cards-v2>
  - 借鉴点：卡片是“可分享的角色设定”，而不是一段散乱的 prompt；
  - 用在：角色设定编辑器把“人设补充/称呼/关系/声线”拆成可编辑字段。

## AI 陪伴类产品与 UI

- **Replika 的 12 个设计秘诀**（优设网译文）
  <https://www.uisdc.com/replika-ais-secret>
  - 借鉴点：角色要有“持续存在的状态”（心情、关系、记忆），互动要有即时反馈；
  - 用在：档案页的关系网、小秘密、今日好感增长、声音试听；舞台上摸头/戳脸/抱抱的不同动作与表情。
- **Flutter AI 陪伴应用 Emo（Gemini）**
  <https://github.com/Kaelith69/Emo>
  - 借鉴点：深色、低干扰的聊天界面，上下文记忆，保存下来的回复；
  - 用在：长台词走底部字幕卡、消息长按“记进记忆册”、聊天面板克制配色。
- **AI 聊天应用 ynadtiy19/ai（Flutter + Gemini）**
  <https://github.com/ynadtiy19/ai>
  - 借鉴点：本地存储、自适应 UI、对话上下文；
  - 用在：JSON 原子写入、场景/人设设置本地持久化。

## 场景与动效

- **Flutter 官方：AnimatedSwitcher**
  <https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html>
  - 用在：场景切换 700ms 交叉淡入，`layoutBuilder` 强制 `StackFit.expand`，避免首帧尺寸跳变。
- **Flutter 官方：CustomPainter**
  <https://api.flutter.dev/flutter/rendering/CustomPainter-class.html>
  - 用在：雪、樱花、雨、极光、天灯、余烬等氛围粒子；不引入新美术资源。
- **Flutter 官方：RepaintBoundary / 性能最佳实践**
  <https://docs.flutter.dev/perf/best-practices>
  - 用在：背景、每个角色立绘、表情层拆 RepaintBoundary；静态层不随 60fps 主时钟重建。
- **Flutter 官方：Implicit animations**
  <https://docs.flutter.dev/ui/animations/implicit-animations>
  - 用在：场景卡片选中态、秘密卡片展开、底栏状态胶囊。

## 角色与美术

- ZipZipPipe（胖次狐）AI 娘设定图、whale-chan 社区：立绘/头像素材来源，CC-BY-NC-SA。
- `lrplrplrp/dsh-live2d`：大肥鱼 Live2D 公皮来源；Cubism SDK 授权见 README 的 Credits。
- Claude 三张表情差分：来自站内 Claude娘（橘白礼服ver.）设定图，作者 Ninon；授权未明，仅个人非商用演示。

## 没有照搬的部分

- 没有引入 SillyTavern 的整套 prompt 模板；只借用角色卡的可交换数据格式。
- 没有为了“像 Live2D”而把扁平 PNG 自动抠脸；自动分层会产生皮肤补丁、错位嘴和头发残影。
- 没有用第三方 UI 套件替换现有舞台；场景与档案的交互沿用现有设计语言，避免风格割裂。
