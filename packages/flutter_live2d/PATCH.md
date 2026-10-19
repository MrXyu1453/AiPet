# 本仓库对 flutter_live2d 1.0.2 的改动

上游：https://github.com/linh18nd/flutter_live2d （pub.dev `flutter_live2d` 1.0.2）

## 为什么 fork

原版 `Live2DTextureView.onTouchEvent` 永远 `return true`，把落在平台视图矩形内的
所有原生触摸都吃掉。私聊舞台需要在人物身上轻点/双击触发“摸摸头 / 逗她”，
但 Flutter 侧的 `GestureDetector` 收不到这些事件（`IgnorePointer` 也拦不住
Android 平台视图的原生触摸分发）。

## 改了什么

1. **触摸不消费**：`Live2DTextureView.onTouchEvent` 从 `return true` 改成
   `return false`，并设置 `isEnabled = false`、`isClickable = false`。
   宿主舞台用最外层 `Listener` 记录 down/up，自己识别轻点/双击，不再依赖
   `GestureDetector` 与平台视图的 arena。原生 touch 仍会转发给模型。

2. **shader 预编译瘦身**：`CubismShader_OpenGLES2::GenerateShaders` 原来会为
   13 种颜色混合 × 5 种 alpha 混合各编译 6 个 program（约 390 个）。现在
   只编译 Normal / Mask / Copy / SetupMask，其余 `ShaderNames_NormalAtop`
   之后的组合全部复用 Normal program。模拟器实测首开 4.7s → 2.3s。
   代价：依赖 multiply/screen 等高级混合模式的模型需要再按需懒编译。

3. **坏 model3 保护**：`Live2DModel::LoadAssets` 在 `new CubismModelSettingJson`
   后检查 `IsValid()`，解析失败直接返回，不再让 `SetupModel` 对空
   `_jsonValue` 解引用（原版会 SIGSEGV）。坏模型会走 Flutter 的全身立绘 fallback。

4. **诊断日志**：`Live2DPal::LoadFileAsBytes` 记录 `fopen failed` / `asset missing`；
   `LogFunction` 把 Cubism 的解析错误输出到 logcat；`Live2DModel` 只记录
   加载失败的 expression/motion。

## 另一个必须注意的点

Cubism 的 shader 文件不在这个包的 Android assets 里。本仓库把
`CubismFramework/Rendering/OpenGL/Shaders/StandardES/` 的 36 个
`.frag` / `.vert` 复制到了宿主 App 的
`android/app/src/main/assets/FrameworkShaders/`。缺了它们，模型会显示为透明。
