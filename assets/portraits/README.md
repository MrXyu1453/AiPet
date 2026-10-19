# 半身立绘 / 表情差分

当前资产状态（`CharacterPortrait` 会自动读取）：

```
assets/portraits/<id>/base.png          # 512x640 透明半身底图（5 人都有）
assets/portraits/<id>/states/*.png      # 可选：对齐的表情差分
```

- `dafeiyu / gpt / gemini / grok`：官方立绘裁切的 512×640 半身底图，透明背景；目前只有呼吸/摇摆 + 情绪 overlay + 说话波形。
- `claude`：来自官方设定图的三张**对齐脸**（中性 / 闭眼笑 / 撑脸得意），已接入：
  - `base.png` = 中性
  - `states/closed.png` = 闭眼笑（眨眼 / 害羞 / 困倦）
  - `states/smug.png` = 撑脸得意（傲娇 / 得意 / 说话时的口型状态）
  这证明“半身 + 眨眼 + 口型 + 表情”的状态机通路是通的。

## 还缺什么

要补齐另外 4 套，需要**同一角色、同一角度、同一画风**的对齐差分，至少：

- `closed.png`：闭眼（眨眼）
- `talk.png`：张嘴（口型）
- `happy / shy / angry / sad`：可选情绪差分

**不建议**从一张扁平 PNG 自动抠眼睛/嘴巴：试过，会得到皮肤补丁、错位嘴、头发残影，反而破坏原画。优先让美术在分层 PSD 里拆出：

```
head, face, eyes_open, eyes_closed, brows, mouth_closed, mouth_open,
hair_front, hair_back, body, arms, tail/accessories
```

然后导出对齐的 PNG 状态图（本方案），或在 Rive 编辑器里绑定骨骼（见 `../rive/README.md`）。
