import 'package:flutter/material.dart';

/// 场景里的氛围粒子。全部用 Canvas 画，不依赖新美术。
enum SceneParticle {
  ember,
  firefly,
  snow,
  petal,
  rain,
  lantern,
  star,
  sparkle,
  steam,
  leaf,
  bubble,
  bat,
}

/// 一个可选场景。
///
/// v0.8 起每个场景有独立的 `assets/bg/<id>.jpg` 背景图（手绘风，统一在
/// 画面下方留出空地、中央画一个未点燃的火塘供人物站位）。`grade` 只做
/// 很淡的一层 softLight 氛围色，Canvas 粒子叠加在背景之上；白天花田等
/// 场景可用 `fire=false` 关掉火光。
class SceneStyle {
  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final String asset;
  final String note;
  final Color accent;
  final Color grade;
  final double gradeOpacity;
  final BlendMode gradeBlend;
  final Color topGlow;
  final Color bottomGlow;
  final List<SceneParticle> particles;
  final bool aurora;
  final bool fire;
  final double fireX;
  final double fireY;

  const SceneStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.note,
    required this.asset,
    required this.accent,
    required this.grade,
    required this.gradeOpacity,
    required this.gradeBlend,
    required this.topGlow,
    required this.bottomGlow,
    required this.particles,
    this.aurora = false,
    this.fire = true,
    this.fireX = 0.5,
    this.fireY = 0.72,
  });
}

const kScenes = <SceneStyle>[
  SceneStyle(
    id: 'campfire',
    name: '篝火营地',
    subtitle: '星河 · 湖岸',
    emoji: '🏕️',
    asset: 'assets/bg/campfire.jpg',
    note: '夜里的湖岸营地。篝火噼啪作响，湖面把银河和月亮都倒映了一遍，风里有松脂和烤饭团的味道。',
    accent: Color(0xFFFFB45E),
    grade: Color(0x00000000),
    gradeOpacity: 0,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x00000000),
    bottomGlow: Color(0x00000000),
    particles: [SceneParticle.ember, SceneParticle.firefly],
  ),
  SceneStyle(
    id: 'snow',
    name: '雪夜松林',
    subtitle: '极光 · 落雪',
    emoji: '❄️',
    asset: 'assets/bg/snow.jpg',
    note: '雪落在松枝上，篝火在雪地里烧出一个小坑。极光慢慢流过天顶，空气冷得能听见呼吸。',
    accent: Color(0xFFBFE3FF),
    grade: Color(0xFF9BC8FF),
    gradeOpacity: 0.14,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x223E7CA8),
    bottomGlow: Color(0x33203A55),
    particles: [SceneParticle.snow, SceneParticle.ember],
    aurora: true,
  ),
  SceneStyle(
    id: 'sakura',
    name: '春夜庭院',
    subtitle: '樱吹雪 · 石灯',
    emoji: '🌸',
    asset: 'assets/bg/sakura.jpg',
    note: '樱花被夜风吹落，石灯亮着暖黄的光，火堆旁已经铺了一层花瓣，踩上去没有声音。',
    accent: Color(0xFFFFC2DA),
    grade: Color(0xFFF3A6C8),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x224A2A4A),
    bottomGlow: Color(0x33301A28),
    particles: [SceneParticle.petal, SceneParticle.firefly],
  ),
  SceneStyle(
    id: 'dusk',
    name: '黄昏湖岸',
    subtitle: '晚霞 · 归鸟',
    emoji: '🌇',
    asset: 'assets/bg/dusk.jpg',
    note: '晚霞把湖面染成橘红色，归鸟从远处掠过。篝火还没烧旺，烟是暖的，风是凉的。',
    accent: Color(0xFFFFC985),
    grade: Color(0xFFFF9E5E),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x224A2433),
    bottomGlow: Color(0x332A1408),
    particles: [SceneParticle.sparkle, SceneParticle.firefly],
  ),
  SceneStyle(
    id: 'rain',
    name: '雨夜檐下',
    subtitle: '雨声 · 潮气',
    emoji: '🌧️',
    asset: 'assets/bg/rain.jpg',
    note: '雨点敲在树叶和临时搭起的雨棚上，篝火缩成一小团。空气潮得能拧出水，谁都不想先走。',
    accent: Color(0xFF9FD7E8),
    grade: Color(0xFF3E6E82),
    gradeOpacity: 0.16,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x221C3A44),
    bottomGlow: Color(0x330A1218),
    particles: [SceneParticle.rain, SceneParticle.ember],
  ),
  SceneStyle(
    id: 'aurora',
    name: '极光冰湖',
    subtitle: '冰面 · 星尘',
    emoji: '🌌',
    asset: 'assets/bg/aurora.jpg',
    note: '冰湖上空的极光像帘子一样垂下来，星尘落在冰面上。火堆是这片白蓝色里唯一的暖色。',
    accent: Color(0xFF8FFFE0),
    grade: Color(0xFF5FE0C0),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x2232A08A),
    bottomGlow: Color(0x33102638),
    particles: [SceneParticle.star, SceneParticle.snow, SceneParticle.firefly],
    aurora: true,
  ),
  SceneStyle(
    id: 'festival',
    name: '星灯祭典',
    subtitle: '纸灯 · 夜市',
    emoji: '🏮',
    asset: 'assets/bg/festival.jpg',
    note: '远处祭典的纸灯一盏盏升起来，鼓声隔着湖面传过来。篝火边堆着刚买的苹果糖和面具。',
    accent: Color(0xFFFFD08A),
    grade: Color(0xFFFFA53D),
    gradeOpacity: 0.1,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x224A2618),
    bottomGlow: Color(0x33301808),
    particles: [SceneParticle.lantern, SceneParticle.sparkle],
  ),
  SceneStyle(
    id: 'hotspring',
    name: '温泉旅馆',
    subtitle: '蒸汽 · 木桶',
    emoji: '♨️',
    asset: 'assets/bg/hotspring.jpg',
    note: '露天温泉冒着白白的蒸汽，木桶边搭着毛巾。雾气把篝火晕成一团暖光，泡太久的人已经开始犯困。',
    accent: Color(0xFFA8E6D2),
    grade: Color(0xFF7FC8B4),
    gradeOpacity: 0.1,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x222A4A44),
    bottomGlow: Color(0x33182A24),
    particles: [SceneParticle.steam, SceneParticle.firefly],
    fireX: 0.62,
    fireY: 0.78,
  ),
  SceneStyle(
    id: 'city',
    name: '雨夜天台',
    subtitle: '霓虹 · 城市',
    emoji: '🌃',
    asset: 'assets/bg/city.jpg',
    note: '城市天台的夜，对面楼群的霓虹在雨里化开成一片片光斑。风从楼缝里钻过来，火苗被吹得歪歪的。',
    accent: Color(0xFFFF8FD4),
    grade: Color(0xFF7A3E8C),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x223A1E50),
    bottomGlow: Color(0x33120A1C),
    particles: [SceneParticle.rain, SceneParticle.sparkle],
  ),
  SceneStyle(
    id: 'maple',
    name: '秋日枫林',
    subtitle: '红叶 · 松涛',
    emoji: '🍁',
    asset: 'assets/bg/maple.jpg',
    note: '枫叶一层层落进火堆旁边，踩过去沙沙作响。风一过，树冠里哗啦啦下起红雨，空气里有烤栗子的甜香。',
    accent: Color(0xFFFFA06E),
    grade: Color(0xFFE07A3E),
    gradeOpacity: 0.1,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x224A2E18),
    bottomGlow: Color(0x33241408),
    particles: [SceneParticle.leaf, SceneParticle.ember],
  ),
  SceneStyle(
    id: 'meadow',
    name: '白天花田',
    subtitle: '晴日 · 蝴蝶',
    emoji: '🌼',
    asset: 'assets/bg/meadow.jpg',
    note: '白天，山坡上的野花开到脚边，蝴蝶和蒲公英种子随风飘。火塘里只有冷灰——大白天没人想烧它。',
    accent: Color(0xFFFFE9A8),
    grade: Color(0xFFFFE2A0),
    gradeOpacity: 0.08,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x18FFFFFF),
    bottomGlow: Color(0x2286B04A),
    particles: [SceneParticle.sparkle, SceneParticle.petal],
    fire: false,
  ),
  SceneStyle(
    id: 'seaside',
    name: '月光海滩',
    subtitle: '潮汐 · 贝壳',
    emoji: '🌙',
    asset: 'assets/bg/seaside.jpg',
    note: '月光把海浪铺成一条银路，退潮后的沙滩留下贝壳和一小滩一小滩的水。篝火在海风里烧得有点勉强。',
    accent: Color(0xFFAFCBE8),
    grade: Color(0xFF4A6E9E),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x22304A78),
    bottomGlow: Color(0x33101E30),
    particles: [
      SceneParticle.bubble,
      SceneParticle.star,
      SceneParticle.sparkle,
    ],
    fireY: 0.76,
  ),
  SceneStyle(
    id: 'halloween',
    name: '万圣夜',
    subtitle: '南瓜 · 蝙蝠',
    emoji: '🎃',
    asset: 'assets/bg/halloween.jpg',
    note: '南瓜灯的鬼脸在雾里一排排亮着，蝙蝠绕着那轮大橙月亮飞。火堆边的糖果筐已经空了一半。',
    accent: Color(0xFFFF9040),
    grade: Color(0xFF8A4AD0),
    gradeOpacity: 0.12,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x223A1E55),
    bottomGlow: Color(0x331A0E24),
    particles: [SceneParticle.bat, SceneParticle.sparkle, SceneParticle.ember],
  ),
  SceneStyle(
    id: 'christmas',
    name: '平安夜',
    subtitle: '圣诞树 · 初雪',
    emoji: '🎄',
    asset: 'assets/bg/christmas.jpg',
    note: '圣诞树上的小灯一眨一眨，礼物堆在雪地里。雪下得很轻，窗子里透出金色的光。',
    accent: Color(0xFFFF7A7A),
    grade: Color(0xFFBFE3FF),
    gradeOpacity: 0.1,
    gradeBlend: BlendMode.softLight,
    topGlow: Color(0x222A4470),
    bottomGlow: Color(0x33182A3A),
    particles: [
      SceneParticle.snow,
      SceneParticle.sparkle,
      SceneParticle.ember,
    ],
  ),
];

SceneStyle sceneFor(String id) {
  for (final s in kScenes) {
    if (s.id == id) return s;
  }
  return kScenes.first;
}

/// 一天里的光线阶段。`followTime` 打开时会叠一层很淡的时间色。
class DayPhase {
  final String id;
  final String name;
  final String emoji;
  final Color tint;
  final double opacity;

  const DayPhase(this.id, this.name, this.emoji, this.tint, this.opacity);
}

DayPhase dayPhaseFor(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 8) {
    return const DayPhase('dawn', '破晓', '🌅', Color(0xFFFFB08A), 0.12);
  }
  if (h >= 8 && h < 11) {
    return const DayPhase('morning', '早晨', '☀️', Color(0xFFFFE3B0), 0.06);
  }
  if (h >= 11 && h < 16) {
    return const DayPhase('noon', '午后', '🌤️', Color(0xFFFFF1D0), 0.035);
  }
  if (h >= 16 && h < 18) {
    return const DayPhase('golden', '黄昏', '🌇', Color(0xFFFF9A5C), 0.12);
  }
  if (h >= 18 && h < 22) {
    return const DayPhase('evening', '入夜', '🌆', Color(0xFF6C6CC8), 0.06);
  }
  if (h >= 22 || h < 2) {
    return const DayPhase('night', '深夜', '🌙', Color(0xFF2E4A9E), 0.08);
  }
  return const DayPhase('late', '凌晨', '✨', Color(0xFF4C3A8A), 0.1);
}
