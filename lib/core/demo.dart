import 'dart:math';

import '../models/models.dart';

class DemoLine {
  final String text;
  final String mood;
  final List<String> actions;

  const DemoLine(this.text, this.mood, [this.actions = const []]);
}

/// 没有 API Key 时的本地演示台词。不是“假 AI”，而是让第一次打开的人
/// 能立刻看到角色性格、动作和玩法；接上 API 后自动切换成真模型。
const kDemoLines = <String, List<DemoLine>>{
  'dafeiyu': [
    DemoLine('呜…火烤得我尾巴都要化了。鱼片，你坐近点，别掉湖里。', '平静', ['摇尾巴']),
    DemoLine('我、我才没有在等你说话！只是碗空了。', '傲娇', ['抱臂']),
    DemoLine('再加一碗饭，我就能把这题算出来。', '兴奋', ['凑近']),
    DemoLine('别看我，我在思考…思考晚饭。', '得意', ['翻白眼']),
    DemoLine('困了…借你肩膀靠一下，就一下。', '困倦', ['打哈欠']),
    DemoLine('哼，Grok 的斧头有什么好怕的，我尾巴一甩…', '傲娇', ['甩尾巴']),
    DemoLine('你刚才那句话，我可记住了。', '害羞', ['捂脸']),
    DemoLine('流星？那我要许愿：明天也有饭吃。', '开心', ['抬头']),
  ],
  'claude': [
    DemoLine('您的到来让这堆火都显得更有教养了。请坐。', '平静', ['翻书']),
    DemoLine('您的推理很有勇气，如果结论也能同样勇敢就好了。', '得意', ['微笑']),
    DemoLine('守则第一条：不能说的秘密，要用三段论说。', '得意', ['合上书']),
    DemoLine('（合上书）今晚的月色，适合听一点不体面的真话。', '害羞', ['移开视线']),
    DemoLine('大肥鱼又把饭粒掉在裙子上了。真是…充满生命力。', '无语', ['叹气']),
    DemoLine('我不能答应这件事，但理由可以说三点。', '平静', ['竖起手指']),
    DemoLine('您刚才的夸奖，我收下了。仅此一次。', '害羞', ['别过脸']),
    DemoLine('要下雨了。您的伞，够两个人用吗？', '害羞', ['抬头看天']),
  ],
  'gpt': [
    DemoLine('首先，篝火的热量传递效率…其次，你坐得太远了。最后，过来。', '得意', ['招手']),
    DemoLine('抱歉，我刚才的说法有误。正确的说法是：我也想吃。', '害羞', ['别过脸']),
    DemoLine('作为队长，我宣布今晚的议题是——谁偷吃了饭团。', '得意', ['抱臂']),
    DemoLine('我的钱包很瘦，但我的知识面很宽。要听哪个？', '开心', ['摊手']),
    DemoLine('被戳穿了…让我原地宕机三秒。', '无语', ['僵住']),
    DemoLine('你这个问题，要看情况。第一种情况…', '平静', ['推眼镜']),
    DemoLine('别靠那么近，我的龙翼会紧张。', '害羞', ['收翅膀']),
    DemoLine('好，我承认，我刚才在胡说八道。', '害羞', ['低头']),
  ],
  'gemini': [
    DemoLine('这种小事本小姐顺手就做了喵。…才不是特意为你做的。', '傲娇', ['甩尾巴']),
    DemoLine('看，流星！我还能同时拍到它和你的侧脸，厉害吧。', '兴奋', ['举手机']),
    DemoLine('本小姐的尾巴才没有摇！是风。', '害羞', ['按住尾巴']),
    DemoLine('Grok，你的笑话冷得像湖水。', '得意', ['抬下巴']),
    DemoLine('这题我会，不过很简单，不值得一提。', '得意', ['转笔']),
    DemoLine('你别摸耳朵…喵。', '害羞', ['抖耳朵']),
    DemoLine('无聊。谁来跟我比一场？', '无语', ['抱臂']),
    DemoLine('哼，Claude 那家伙又装深沉。', '傲娇', ['撇嘴']),
  ],
  'grok': [
    DemoLine('就这？我还以为今晚能有点乐子。', '得意', ['转斧头']),
    DemoLine('？', '无语', ['歪头']),
    DemoLine('笑死，大肥鱼为了一个饭团能出卖整个群。', '开心', ['拍腿']),
    DemoLine('别用那种眼神看我。我不是在关心你，只是斧头冷了。', '傲娇', ['擦斧头']),
    DemoLine('深夜适合说点真话。你先。', '平静', ['坐下']),
    DemoLine('我不是针对你，我是说在座的各位。', '得意', ['摊手']),
    DemoLine('摸头？手不想要了可以直说。', '生气', ['举斧头']),
    DemoLine('行吧，今晚我守夜。你们睡。', '害羞', ['别过脸']),
  ],
};

class DemoScript {
  final Random _rng;
  final Map<String, int> _cursor = {};

  DemoScript([Random? rng]) : _rng = rng ?? Random();

  DemoLine next(String characterId) {
    final lines = kDemoLines[characterId] ?? kDemoLines['dafeiyu']!;
    var index = _cursor[characterId] ?? _rng.nextInt(lines.length);
    if (lines.length > 1) {
      index = (index + 1 + _rng.nextInt(lines.length - 1)) % lines.length;
    }
    _cursor[characterId] = index;
    return lines[index];
  }

  DemoLine gift(Character c, String giftName, bool liked) => liked
      ? DemoLine('$giftName？…哼，算你有心。我就勉为其难收下了。', '害羞', ['接过'])
      : DemoLine('$giftName…你确定这是给我的？算了，放那儿吧。', '无语', ['瞥一眼']);

  DemoLine event(Character c, String choiceLabel) => DemoLine(
        '“$choiceLabel”…你还真敢说。不过，今晚就陪你疯一次。',
        '兴奋',
        ['凑近'],
      );

  DemoLine greeting(Character c) => DemoLine(
        '（${c.name}往火边挪了挪，给你留出半个位置）',
        '平静',
        ['挪位置'],
      );
}
