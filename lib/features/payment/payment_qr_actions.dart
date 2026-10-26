import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

enum QrShareOutcome { completed, dismissed, unknown }

/// Actions receive only a standalone QR PNG, never a screenshot of an invite
/// or document. Prepared bytes allow sharing directly from a user gesture.
class PaymentQrActions {
  const PaymentQrActions();

  Future<Uint8List> render(String payload) async {
    final qr = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    const scale = 12;
    const quietModules = 4;
    final pixels = (qr.moduleCount + 2 * quietModules) * scale;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble()),
      ui.Paint()..color = const ui.Color(0xffffffff),
    );
    canvas.translate(
      quietModules * scale.toDouble(),
      quietModules * scale.toDouble(),
    );
    QrPainter.withQr(qr: qr, gapless: true).paint(
      canvas,
      ui.Size(
        qr.moduleCount * scale.toDouble(),
        qr.moduleCount * scale.toDouble(),
      ),
    );
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(pixels, pixels);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Không tạo được PNG.');
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  Future<void> save(Uint8List png, String fileBase) async {
    await FileSaver.instance.saveFile(
      name: fileBase,
      bytes: png,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }

  Future<QrShareOutcome> share(
    Uint8List png,
    String fileBase,
    ui.Rect origin,
  ) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['$fileBase.png'],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => QrShareOutcome.completed,
      ShareResultStatus.dismissed => QrShareOutcome.dismissed,
      ShareResultStatus.unavailable => QrShareOutcome.unknown,
    };
  }
}
