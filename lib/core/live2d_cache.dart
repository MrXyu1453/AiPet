import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 与 `flutter_live2d` 的 asset 解包逻辑保持一致：把模型目录提前复制到
/// 临时目录，并写上 `.ready` 标记。这样第一次打开私聊时不用再等 2MB+
/// 的文件从 APK 解包。
///
/// 这里不依赖插件内部 API，路径/标记与插件 1.0.2 完全一致；即使预解包
/// 失败，插件自己的 `loadModel` 仍然会兜底解包。
const _modelDirs = <String>[
  'assets/live2d/dafeiyu/',
];

// 模型资产（表情/动作/纹理）变化时递增；旧缓存会被删掉重解包，
// 避免插件按目录名缓存后继续用旧模型。
const _cacheVersion = 'dafeiyu-2026-10-19-v6';

Future<void>? _done;

Future<void> prewarmLive2DModels() async {
  final running = _done;
  if (running != null) return running;
  _done = Future.wait(_modelDirs.map(_prewarmOne));
  return _done;
}

Future<void> _prewarmOne(String assetDir) async {
  try {
    final normalized = assetDir.endsWith('/') ? assetDir : '$assetDir/';
    final temp = await getTemporaryDirectory();
    final key = base64UrlEncode(utf8.encode(normalized)).replaceAll('=', '');
    final outDir = Directory('${temp.path}/flutter_live2d_models/$key/');
    final marker = File('${outDir.path}.ready');
    final versionFile = File('${outDir.path}.version');
    if (await marker.exists() &&
        await versionFile.exists() &&
        (await versionFile.readAsString()) == _cacheVersion) {
      return;
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys =
        manifest.listAssets().where((k) => k.startsWith(normalized)).toList();
    if (keys.isEmpty) return;

    if (await outDir.exists()) {
      await outDir.delete(recursive: true);
    }
    if (await marker.exists()) await marker.delete();
    await outDir.create(recursive: true);
    for (final k in keys) {
      final relative = k.substring(normalized.length);
      final file = File('${outDir.path}$relative');
      await file.parent.create(recursive: true);
      final data = await rootBundle.load(k);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    await marker.writeAsString('ok', flush: true);
    await versionFile.writeAsString(_cacheVersion, flush: true);
  } catch (_) {
    // 预解包失败时保持安静，真正的加载路径会自己解包。
  }
}
