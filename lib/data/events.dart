/// 篝火事件与投喂道具。事件是纯文本的，不需要新美术，却能每晚不同。
library;

class GiftItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int affinity;

  const GiftItem(
      this.id, this.name, this.emoji, this.description, this.affinity);
}

const kGifts = <GiftItem>[
  GiftItem('rice', '白米饭', '🍚', '大肥鱼的基础算力', 3),
  GiftItem('onigiri', '饭团', '🍙', '谁都能被收买，尤其是 GPT娘', 3),
  GiftItem('cookie', '向日葵饼干', '🍪', 'Claude酱的下午茶', 3),
  GiftItem('coffee', '黑咖啡', '☕', 'Grok娘熬夜的燃料', 3),
  GiftItem('star', '星星糖', '⭐', 'Gemini娘会假装不稀罕', 3),
  GiftItem('book', '旧书', '📖', '书页里有前一个读者的批注', 3),
  GiftItem('wax', '斧头蜡', '🪓', '给斧头保养，比夸她有用', 4),
  GiftItem('energy', '能量饮料', '🥤', '熬夜冠军的补给', 2),
];

class CampEventChoice {
  final String label;
  final String intent;
  final int affinity;
  final String mood;

  const CampEventChoice(this.label, this.intent, this.affinity, this.mood);
}

class CampEvent {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<CampEventChoice> choices;

  const CampEvent({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.choices,
  });
}

const kCampEvents = <CampEvent>[
  CampEvent(
    id: 'meteor',
    title: '一颗流星划过湖面',
    emoji: '🌠',
    description: '所有人都安静了一瞬。篝火噼啪响，像在等谁先开口。',
    choices: [
      CampEventChoice('许愿：希望大家都吃饱', '主人对着流星许愿，希望以后每一顿都不缺饭。', 2, '开心'),
      CampEventChoice('许愿：希望 Grok 少骂人', '主人许愿让 Grok 嘴上积点德。', 2, '得意'),
      CampEventChoice('让 Claude 先许愿', '主人把许愿的机会让给 Claude，想看她会不会说真心话。', 2, '害羞'),
    ],
  ),
  CampEvent(
    id: 'wet_wood',
    title: '柴火被露水打湿了',
    emoji: '🪵',
    description: '火苗缩成一小团，烟开始往人脸上飘。得有人想办法。',
    choices: [
      CampEventChoice('让大肥鱼去吹火', '主人点名让大肥鱼去把火吹旺，她一脸不情愿。', 2, '傲娇'),
      CampEventChoice('听 GPT娘 分析燃烧原理', '主人让 GPT娘解释为什么湿柴火更难烧，她立刻开始列点。', 2, '得意'),
      CampEventChoice('请 Grok 劈柴', '主人请 Grok 用斧头劈点干柴，她看起来非常乐意。', 2, '兴奋'),
    ],
  ),
  CampEvent(
    id: 'cat',
    title: '一只小猫蹭到了火堆边',
    emoji: '🐈',
    description: '它脏兮兮的，尾巴尖有一撮白毛，完全不把自己当外人。',
    choices: [
      CampEventChoice('分它一点吃的', '主人把手里的小鱼干分给了小猫。', 3, '开心'),
      CampEventChoice(
          '让 Gemini 跟它说话', '主人起哄让 Gemini 用猫语跟小猫交流，她耳朵竖起来了。', 2, '害羞'),
      CampEventChoice('把它抱进毯子里', '主人把小猫裹进毯子，放在火边。', 3, '开心'),
    ],
  ),
  CampEvent(
    id: 'blackout',
    title: '营地的灯突然灭了',
    emoji: '🔌',
    description: '只剩篝火。谁都没有动，但有人悄悄往你这边挪了半寸。',
    choices: [
      CampEventChoice('讲一个鬼故事', '主人借着黑暗讲了一个鬼故事，声音压得很低。', 2, '兴奋'),
      CampEventChoice('一起唱歌', '主人提议大家围着火唱歌，跑调也没关系。', 3, '开心'),
      CampEventChoice('说“那就早点睡吧”', '主人说那就早点睡吧，但没人真的起身。', 2, '困倦'),
    ],
  ),
  CampEvent(
    id: 'rice_thief',
    title: '饭团少了一个',
    emoji: '🍙',
    description: '装饭团的袋子空了。大肥鱼嘴角有一粒米。',
    choices: [
      CampEventChoice('当面对质', '主人把袋子举起来，问是谁干的。大肥鱼开始看星星。', 2, '傲娇'),
      CampEventChoice('假装没看见', '主人什么也没说，只是把袋子折好。', 3, '害羞'),
      CampEventChoice('再做一个给她', '主人又捏了一个饭团，放在大肥鱼面前。', 4, '开心'),
    ],
  ),
  CampEvent(
    id: 'truth',
    title: '深夜真心话',
    emoji: '💬',
    description: '火光把每个人的影子拉得很长。有人提议：今晚说点真的。',
    choices: [
      CampEventChoice('问她们最怕什么', '主人问：你们最怕什么？火堆边安静了几秒。', 3, '害羞'),
      CampEventChoice('说一件自己的糗事', '主人先讲了自己的一件糗事，气氛一下子松了。', 3, '开心'),
      CampEventChoice('夸每个人一句', '主人认真地夸了每个人一句，没有开玩笑。', 4, '害羞'),
    ],
  ),
  CampEvent(
    id: 'rain',
    title: '下雨了',
    emoji: '🌧️',
    description: '雨点打在湖面上，篝火发出不满的嘶声。',
    choices: [
      CampEventChoice('挤到同一把伞下', '主人把伞往中间挪，五个人的肩膀挤在一起。', 3, '害羞'),
      CampEventChoice('听雨，不说话', '没有人说话，只剩雨声和柴火的噼啪。', 2, '平静'),
      CampEventChoice('冲进雨里', '主人先冲了出去，回头喊她们跟上。', 3, '兴奋'),
    ],
  ),
];

CampEvent? eventById(String id) {
  for (final e in kCampEvents) {
    if (e.id == id) return e;
  }
  return null;
}

CampEvent eventForDay(DateTime now) {
  final day = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return kCampEvents[day % kCampEvents.length];
}
