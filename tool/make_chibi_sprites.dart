// 把 ImageGen 仿 ZipZipPipe 官方造型生成的白底 Q 版立绘转成透明背景 chibi.png
// 用法: dart run tool/make_chibi_sprites.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const ids = ['dafeiyu', 'claude', 'gpt', 'gemini', 'grok'];
const targetH = 640;

void main() {
  for (final id in ids) {
    final src = File('F:/program/AiPet/references/chibi_gen/$id.png');
    final decoded = img.decodePng(src.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('$id: decode failed');
      continue;
    }
    final im = decoded;
    final w = im.width, h = im.height;
    final out =
        im.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);

    bool isWhite(img.Pixel p) => p.r > 232 && p.g > 232 && p.b > 232;

    // 从四边泛洪填充去白底（保留衣服内部白色，如大肥鱼围裙/GPT娘白裙）
    final removed = List<bool>.filled(w * h, false);
    final stack = <int>[];
    void seed(int x, int y) {
      final i = y * w + x;
      if (!removed[i] && isWhite(out.getPixel(x, y))) {
        removed[i] = true;
        stack.add(i);
      }
    }
    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w, y = i ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (removed[y * w + x]) out.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }

    // 边缘一圈半透明羽化，消除硬锯齿
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (removed[i]) continue;
        var n = 0;
        if (removed[i - 1]) n++;
        if (removed[i + 1]) n++;
        if (removed[i - w]) n++;
        if (removed[i + w]) n++;
        if (n > 0) {
          final p = out.getPixel(x, y);
          out.setPixelRgba(
              x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), (255 * (4 - n) / 4).round());
          if (n >= 2 && isWhite(p)) {
            out.setPixelRgba(x, y, (p.r * 0.6).round(), (p.g * 0.6).round(),
                (p.b * 0.7).round(), (255 * (4 - n) / 4).round());
          }
        }
      }
    }

    // 裁剪到内容包围盒
    var minX = w, minY = h, maxX = 0, maxY = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (out.getPixel(x, y).a > 10) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    final cw = maxX - minX + 1, ch = maxY - minY + 1;
    final cropped = img.copyCrop(out, x: minX, y: minY, width: cw, height: ch);
    final scale = targetH / ch;
    final resized = img.copyResize(cropped,
        width: (cw * scale).round(), height: targetH);

    final dst =
        File('F:/program/AiPet/aining_app/assets/sprites/$id/chibi.png');
    dst.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('$id: ${resized.width}x${resized.height} -> ${dst.path}');
  }
}
