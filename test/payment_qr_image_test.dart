import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/payment/payment_qr_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:zxing2/qrcode.dart';

import 'fixtures/payment_draft.dart';
import 'helpers/vietqr_reference_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'standalone white PNG with quiet zone is decoded independently by ZXing',
    () async {
      final payment = PaymentDetails.fromDraft(paymentDraft());
      final bytes = await const PaymentQrActions().render(payment.payload);
      final png = image.decodePng(bytes)!;
      expect(png.width, png.height);
      // Four quiet modules x 12 pixels, with fully opaque white background.
      for (final point in [(0, 0), (47, 47), (png.width - 1, png.height - 1)]) {
        final pixel = png.getPixel(point.$1, point.$2);
        expect([pixel.r, pixel.g, pixel.b, pixel.a], [255, 255, 255, 255]);
      }
      final source = RGBLuminanceSource(
        png.width,
        png.height,
        png
            .convert(numChannels: 4)
            .getBytes(order: image.ChannelOrder.abgr)
            .buffer
            .asInt32List(),
      );
      final decoded = QRCodeReader()
          .decode(BinaryBitmap(GlobalHistogramBinarizer(source)))
          .text;
      expect(decoded, payment.payload);
      expect(decodeAccountQr(decoded)['accountNumber'], '000000000001');
      expect(decoded, isNot(contains('NGUOI NHAN DEMO')));
      expect(decoded, isNot(contains('#join')));
    },
  );
}
