import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/scenes.dart';
import '../../core/theme.dart';
import '../../state/settings_controller.dart';

Future<void> showSceneSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => const _SceneSheet(),
  );
}

class _SceneSheet extends StatelessWidget {
  const _SceneSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('今晚在哪儿点火？',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.dim,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '场景会改变光线、天气粒子，也会写进她们的提示词——她们真的会“看见”雪或极光。',
            style:
                TextStyle(fontSize: 11.5, height: 1.55, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: [
              for (final scene in kScenes)
                SceneThumb(
                  scene: scene,
                  selected: settings.scene.id == scene.id,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await settings.setScene(scene.id);
                    await HapticFeedback.lightImpact();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.atmosphereEnabled,
                  onChanged: settings.setAtmosphere,
                  activeThumbColor: AppColors.ember,
                  title: const Text('氛围粒子', style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text('雪、花瓣、雨、萤火、天灯、蒸汽、落叶、气泡、蝙蝠；低配设备可关',
                      style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: settings.followTime,
                  onChanged: settings.setFollowTime,
                  activeThumbColor: AppColors.ember,
                  title:
                      const Text('光线随时间变化', style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text('破晓、黄昏、深夜会叠一层很淡的时间色',
                      style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('回营地'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 场景缩略卡片。设置页、引导页和场景面板共用。
class SceneThumb extends StatelessWidget {
  final SceneStyle scene;
  final bool selected;
  final VoidCallback onTap;

  const SceneThumb({
    super.key,
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? scene.accent.withValues(alpha: 0.85)
                : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scene.accent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (scene.gradeOpacity > 0)
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          scene.grade.withValues(alpha: scene.gradeOpacity),
                          scene.gradeBlend,
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            scene.grade.withValues(alpha: 0.22),
                            BlendMode.softLight,
                          ),
                          child: Image.asset(scene.asset,
                              fit: BoxFit.cover,
                              alignment: Alignment.bottomCenter,
                              cacheWidth: 420),
                        ),
                      )
                    else
                      Image.asset(scene.asset,
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                          cacheWidth: 420),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.bg.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 7,
                      child: Text(scene.emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                    if (selected)
                      Positioned(
                        right: 7,
                        top: 7,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: scene.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 13, color: Color(0xFF1A1206)),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: AppColors.surface2,
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scene.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? scene.accent : AppColors.text,
                        )),
                    const SizedBox(height: 2),
                    Text(scene.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
