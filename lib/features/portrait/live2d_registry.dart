/// Live2D 资产登记表。
///
/// 目前只有「大肥鱼」有公开的 Cubism 全身模型（蓝色鲸鱼女仆，作者公开分发的
/// 免费公皮）。其它四位暂时没有可用的 `.moc3`，私聊舞台会自动退回到
/// 「全身立绘 + 网格呼吸」的替身层，而不是拿一个不相干的模型糊弄。
///
/// 把新模型放进 `assets/live2d/<角色 id>/`，在这里补一条记录即可接入：
/// 模型目录、`*.model3.json`、表情顺序（与 model3.json 的 Expressions 一致）
/// 以及 Anima 动作组中 speak / thinkend / thinking 的下标。
library;

class Live2DModelSpec {
  final String directory;
  final String fileName;
  final List<String> expressionNames;
  final int speakMotionIndex;
  final int thinkEndMotionIndex;
  final int thinkingMotionIndex;

  /// Reaction 动作组下标（没有该组时全部保持 0，_safe() 会吞掉错误）。
  final int patMotionIndex;
  final int surpriseMotionIndex;
  final int shyMotionIndex;
  final int bounceMotionIndex;
  final int tailMotionIndex;
  final int waveMotionIndex;

  const Live2DModelSpec({
    required this.directory,
    required this.fileName,
    required this.expressionNames,
    this.speakMotionIndex = 0,
    this.thinkEndMotionIndex = 1,
    this.thinkingMotionIndex = 2,
    this.patMotionIndex = 0,
    this.surpriseMotionIndex = 1,
    this.shyMotionIndex = 2,
    this.bounceMotionIndex = 3,
    this.tailMotionIndex = 4,
    this.waveMotionIndex = 5,
  });

  int? expressionIndex(String name) {
    final i = expressionNames.indexOf(name);
    return i < 0 ? null : i;
  }
}

const kLive2DModels = <String, Live2DModelSpec>{
  'dafeiyu': Live2DModelSpec(
    directory: 'assets/live2d/dafeiyu/',
    fileName: 'deepseek.model3.json',
    expressionNames: [
      'happy',
      'happy2',
      'puzzled',
      'relax',
      'unhappy',
      'shy',
      'pout',
      'surprised',
      'sleepy',
      'smug',
      'wink',
      'sad',
      'love',
      'angry',
    ],
  ),
};

Live2DModelSpec? live2dSpecFor(String characterId) =>
    kLive2DModels[characterId];
