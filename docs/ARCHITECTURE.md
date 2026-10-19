# 架构说明（v0.9）

## 1. 一句话

Flutter 单页应用：一个可换场景的「篝火舞台」+ 群聊/私聊 + 本地状态（情绪、好感、记忆）
+ OpenAI 兼容的流式聊天。所有视觉资产都在本机，音频运行时合成。

## 2. 分层

```
lib/
  main.dart                 启动、Provider 注入、Live2D 预热
  core/                     领域服务与基础设施
    api_client.dart          OpenRouter/OpenAI 兼容、SSE、错误分类
    chat_engine.dart         提示词组装 + 流式 + 演示台词
    prompts.dart             系统提示词、心情/动作解析
    director.dart            本地导演：@、引用、心情、好感加权
    camp_state.dart          情绪衰减、好感、记忆、夜次
    scenes.dart              场景目录、天气粒子、时间阶段
    theme.dart               颜色、圆角、Material 3 主题
    storage.dart             原子 JSON、聊天存档、Markdown 导出
    audio_*.dart             合成 BGM / 环境音 / SFX
    voice_service.dart       系统 TTS
  data/
    characters.dart          官方人设、二创覆盖合并、characterById
    events.dart              事件卡、投喂道具
    personas.dart            二创持久化、Character Card V2 导入导出
  models/models.dart         Character / Message / Emotion / Affinity / Memory
  state/
    chat_session.dart        群聊/私聊共同接口（含发表情包）
    chat_controller.dart     群聊调度、事件、投喂、演唱会、真心话
    private_chat_controller.dart
    settings_controller.dart 连接、场景、体验设置
  features/
    chat/                    舞台入口、聊天面板、快捷互动、气泡
    campfire/                舞台、角色动作、氛围粒子、事件、节奏游戏
    scenes/                  场景选择面板与缩略卡
    persona/                 角色设定编辑器
    portrait/                半身像、表情状态机、Live2D/Rive 桥接
    profile/                 档案、关系网、秘密、投喂
    private/                 私聊与 Live2D 全身舞台
    memory/                  记忆册
    settings/                设置、引导
```

依赖方向：`features -> state -> core/data -> models`。`core` 不反向依赖 `state` 或 `features`。

## 3. 群聊数据流

```
用户输入 / 戳一戳 / 投喂 / 事件 / 表情包 / 演唱会 / 闲置
  -> ChatController 串行任务队列（同一时间只有一个任务）
     -> 写入用户消息或系统事件、记忆抽取
     -> 本地导演选人 Director.pickResponders
     -> ChatEngine.generate(character)
        -> PromptBuilder.systemFor
           - 官方人设 + 二创补充
           - 场景 note（SceneStyle.note）
           - 营地状态：时间/场景/心情/好感/记忆
           - 关系网 / 小秘密 / 专属称呼
        -> ApiClient.streamChat（SSE，30 秒无新内容超时）
        -> parseReply 解析 [心情]/[动作]
     -> 逐段更新占位消息（isStreaming）
     -> camp.setEmotion / addAffinity
     -> 可选的接话链、表情包消息
     -> VoiceService 串行 TTS 队列（一句播完再播下一句）
```

**轮流发言约束**：`_speakNow()` 只能在串行任务里调用。任务返回前会等待流式
结束和消息间停顿，因此下一位角色不会在上一句的 `isStreaming` 还没结束时
开始生成。UI 里 `typingIds` 任何时刻最多只有一个角色。

## 4. 场景系统

`SceneStyle`（`core/scenes.dart`）描述：

| 字段 | 作用 |
| --- | --- |
| `asset` | 独立背景图 `assets/bg/<id>.jpg`（v0.8 起每场景一张，构图统一：下方留空地、中央未点燃火塘） |
| `grade` / `gradeOpacity` / `gradeBlend` | 背景整体调色（softLight） |
| `topGlow` / `bottomGlow` | 顶部天空、底部地面的光晕渐变 |
| `particles` | 雪 / 花瓣 / 雨 / 萤火 / 天灯 / 星尘 / 极光 / 余烬 / 蒸汽 / 落叶 / 气泡 |
| `aurora` | 是否绘制极光带 |
| `fire` / `fireX` / `fireY` | 火光位置；以后换成没有篝火的场景可以关掉 |
| `note` | 写进提示词的“眼前”描述 |

`SceneAtmosphere`（`features/campfire/scene_atmosphere.dart`）用一个 `CustomPainter`
在 60fps 主时钟上画粒子；低配模式会把粒子数量减半。场景切换由
`AnimatedSwitcher` + `StackFit.expand` 做 700ms 交叉淡入。

时间阶段 `DayPhase` 在 `followTime` 打开时叠一层很淡的渐变，不改变背景结构。

## 5. 角色二创系统

官方人设是 `kCharacters`（const）。用户修改存为 `PersonaOverride`，语义是增量：

- 名字 / 称号 / 专属称呼；
- 性格、说话方式、关系的追加段落；
- 追加口头禅、喜欢、讨厌；
- 可选的 TTS pitch / rate。

`PersonaStore` 持久化到 `personas.json`，加载后调用
`applyPersonaOverrides(...)`，之后所有 `characterById(id)` 都返回合并后的角色：

```
kCharacters[id] --merge(PersonaOverride)--> characterById(id)
```

需要遍历全部角色且要显示自定义名字时，用 `resolvedCharacters`。

提示词里会额外注入：

- `关系网`：对另外四人的具体关系；
- `【不会主动说出口的事】`：小秘密，被戳中时可以嘴硬或露破绽；
- 专属称呼。

角色卡导出格式同时兼容本应用与
[SillyTavern Character Card V2](https://github.com/malfoyslastname/character-card-spec-v2)：
每张卡是 `{spec, spec_version, data}`，本应用字段放在
`data.extensions.aining`，包括 `character_id`、`bonds`、`secret`、`override`。
导入时优先读 `overrides`，没有则读 `cards` / 单张 `data`。

## 6. 性能约束

- 舞台拆层：背景、气泡、名字胶囊、字幕卡是静态层；只有火光、人物、余烬、
  氛围粒子随主时钟重建。
- 五个角色立绘使用 `ui.Image` 并限制解码宽度 480；Live2D 只在私聊里实例化。
- 场景粒子使用确定性伪随机（不分配大量对象），低配减半。
- 私聊 Live2D：后台预解包、shader 预编译、surface 轮询 60ms、静态立绘淡入。
- 气泡 TTL 用 4fps 轻量刷新，不把整棵舞台拖回 60fps。

## 7. 扩展点

- **新增场景**：在 `kScenes` 加一条；如果要独立美术，改 `asset`。
- **新增角色**：在 `kCharacters` 加数据，补齐头像/立绘/表情包；`characterById` 自动可用。
- **接入新模型**：设置页填 Base URL / Key / 模型；支持逐角色覆盖。
- **新互动**：在 `ChatController` 加一个发起方法 + 在 `quick_actions.dart` 加入口；
  状态写 `CampState`，提示词里就能用。
- **Rive / Live2D**：`character_visual.dart` 的 `_SpriteLayer` 与
  `character_portrait.dart` 是替换点；对外输入仍是 mood / talking / blink。

## 8. 测试

- `test/core_test.dart`：URL 归一化、回复解析、情绪衰减、好感上限、导演 @。
- `test/chat_panel_test.dart`：360×800 / 320×640 聊天面板不溢出。
- `test/widget_test.dart`：角色数据、消息 JSON、旧消息兼容。
- `test/portrait_test.dart`：半身像 fallback、Claude 表情状态。
- `test/scene_persona_test.dart`：场景完整性、时间阶段、二创合并、提示词注入。

## 9. 下一步

1. 为 7 个场景补独立背景美术（现在共用一张营地底图）。
2. 角色卡导入时生成“关系网 / 秘密”的可视化编辑。
3. 桌面小组件 / 通知 / 语音输入。
4. 每晚异步摘要记忆，减少手动记忆册。
5. 把二创导出为可分享的 `.png` 角色卡（立绘 + 设定卡）。
