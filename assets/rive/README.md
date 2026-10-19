# Rive 资产约定（可选）

把导出的 Rive 文件放到：

```
assets/rive/dafeiyu.riv
assets/rive/claude.riv
assets/rive/gpt.riv
assets/rive/gemini.riv
assets/rive/grok.riv
```

`CharacterPortrait` 会先探测该文件；存在就走 Rive，不存在就回退到
`assets/portraits/<id>/base.png` + 情绪 overlay（当前默认路径）。

## Rive 工程规格

- Artboard：`Portrait`
- State Machine：`Portrait`
- 画布：512×640（或同比例），透明背景
- 输入（名字必须一致）：

| 输入 | 类型 | 含义 |
|---|---|---|
| `mood` | Number | 0 开心 / 1 傲娇 / 2 生气 / 3 困倦 / 4 得意 / 5 害羞 / 6 无语 / 7 兴奋 / 8 平静 / 9 难过 |
| `talking` | Boolean | 是否正在说话/生成/TTS |
| `blink` | Trigger | 眨一次眼 |
| `mouth` | Number | 0 闭嘴 → 1 张嘴；代码在 talking 时以 260ms 往返驱动 |

Dart 侧桥接在 `lib/features/portrait/character_portrait.dart` 的 `_RivePortrait`。

## 分层建议

```
Root
├─ Body (含衣服、肩膀)
├─ HairBack
├─ Head
│  ├─ Face (含耳朵/腮红底)
│  ├─ Brows
│  ├─ EyesOpen / EyesClosed (互斥)
│  ├─ MouthClosed / MouthOpen (或用 mouth 数值驱动)
│  └─ HairFront
├─ Arms (可选)
└─ Accessories (尾巴、斧头、书本、龙翼)
```

眨眼组只做 100-140ms；口型用 `mouth` 驱动 2-3 帧（闭/半开/开）即可，不必逐音素。

## 性能

- 5 个全身 Live2D/Rive 同时 60fps 对中端机偏重：只让**当前说话者**全动态，其他人低频待机。
- 我们的 `CharacterPortrait` 只在资料页/私聊头部出现，天然只有 1 个实例，适合做全动态。
