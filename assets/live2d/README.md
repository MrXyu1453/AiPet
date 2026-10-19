# Live2D 资产约定

私聊全身舞台会先看 `lib/features/portrait/live2d_registry.dart` 里有没有该角色的记录：

- 有记录 → 用 `flutter_live2d` 加载 `<directory>/<fileName>`；
- 没有记录 → 退回 `assets/sprites/<id>/f0.png`（或 `chibi.png`）的
  网格形变全身立绘，角标显示“全身立绘”。

## 当前模型

| 角色 | 目录 | 模型 | 说明 |
|---|---|---|---|
| 大肥鱼 `dafeiyu` | `assets/live2d/dafeiyu/` | `deepseek.model3.json` | 公开分发的蓝色鲸鱼女仆 Cubism 模型；Idle + Anima（speak / thinkend / thinking）+ Reaction（nod / surprise / shy / bounce / tailwag / wave）+ 14 个表情 |

模型权利归原作者，仅限非商业个人项目；正式分发前请替换为自有授权资产。

## 文件结构

```
assets/live2d/dafeiyu/
  deepseek.model3.json
  deepseek.moc3
  deepseek.physics3.json
  deepseek.cdi3.json
  texture_00.png                 # 2048×2048；这个模型的 UV 与纹理像素绑定，降到 1024 会整只透明
  idle.motion3.json
  speak.motion3.json
  thinking.motion3.json
  thinkend.motion3.json
  nod.motion3.json               # Reaction 0
  surprise.motion3.json          # Reaction 1
  shy.motion3.json               # Reaction 2
  bounce.motion3.json            # Reaction 3
  tailwag.motion3.json           # Reaction 4
  wave.motion3.json              # Reaction 5
  happy.exp3.json
  happy2.exp3.json
  puzzled.exp3.json
  relax.exp3.json
  unhappy.exp3.json
  shy.exp3.json
  pout.exp3.json
  surprised.exp3.json
  sleepy.exp3.json
  smug.exp3.json
  wink.exp3.json
  sad.exp3.json
  love.exp3.json
  angry.exp3.json
```

新增的 `Reaction` 动作和 9 个表情由 `tool/gen_live2d_anim.py` 生成。
它们只改现有模型的参数（头/眼/眉/嘴/身体/头发/尾巴），不需要新的 moc3 或美术。
改曲线后重新跑一遍脚本即可；同时把 `lib/core/live2d_cache.dart` 里的
`_cacheVersion` 递增，旧缓存会自动失效。

注意两个格式约束：

- `model3.json` 的 Motions 条目只能写 `File`，不要写 `FadeInTime/FadeOutTime`
  （它们在 motion3 文件的 `Meta` 里）；写错会让 Cubism 解析失败并原生崩溃。
- 手写的 `motion3.json` 用**带缩进、结尾换行**的格式。Cubism 自带的 JSON
  解析器对单行压缩的 motion3 会报 `Json parse error @line 1`。
- 本仓库生成器用线性段（segment id 0）而不是 Bézier，兼容性最好；短反应
  动作靠多打几个关键点就足够顺。

`pubspec.yaml` 只需要声明目录：

```yaml
flutter:
  assets:
    - assets/live2d/dafeiyu/
```

`flutter_live2d` 会在首次加载时把该目录下的所有文件复制到应用缓存，
所以模型引用的纹理 / 动作 / 表情路径都必须是**相对该目录**的路径。

## 新增一个角色

1. 把模型文件夹放到 `assets/live2d/<角色 id>/`，确认里面有一个
   `*.model3.json`，以及它引用的 `.moc3`、纹理、动作、表情、物理文件。
2. 在 `pubspec.yaml` 的 `assets:` 里加 `- assets/live2d/<角色 id>/`。
3. 在 `lib/features/portrait/live2d_registry.dart` 里加一条
   `Live2DModelSpec`：
   - `directory` / `fileName`：模型目录和 model3 文件名；
   - `expressionNames`：**必须和 model3.json 的 Expressions 顺序一致**；
   - `speakMotionIndex` / `thinkEndMotionIndex` / `thinkingMotionIndex`：
     Anima 动作组里的下标。
4. 如果角色没有 Anima 组，把三个下标都设为 0，或让 `startMotion`
   走空实现——`_safe()` 会吞掉“没有这个动作组”的错误，不影响待机。

## 必须随 APK 打包的 shader

`flutter_live2d` 的 Android 工程没有把 Cubism 的 shader 放进 APK assets。
没有它们时 `loadModel` 仍返回 true，但 shader program 是 0，模型完全透明。

本仓库把 `CubismFramework/Rendering/OpenGL/Shaders/StandardES/` 下的
36 个 `.frag` / `.vert` 复制到了：

```
android/app/src/main/assets/FrameworkShaders/
```

升级插件时先确认这个目录还在；缺文件的表现就是“Live2D · 全身”角标亮着，
但舞台上看不到人。
