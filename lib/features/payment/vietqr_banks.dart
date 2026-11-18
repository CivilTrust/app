/// Commonly used Vietnamese banks and their NAPAS/VietQR acquirer BINs.
///
/// Static reference list bundled with the app (no network lookup). It is a
/// convenience for choosing a bank, not proof that an account exists. Banks
/// not listed can still be entered by BIN. Review against the current NAPAS
/// list before production.
class VietQrBank {
  const VietQrBank(this.bin, this.shortName, this.name);
  final String bin;
  final String shortName;
  final String name;

  String get label => '$shortName — $name';

  bool matches(String query) {
    final q = _fold(query.trim());
    if (q.isEmpty) return true;
    return _fold(shortName).contains(q) ||
        _fold(name).contains(q) ||
        bin.contains(q);
  }
}

const vietQrBanks = [
  VietQrBank('970436', 'Vietcombank', 'Ngân hàng TMCP Ngoại thương Việt Nam'),
  VietQrBank('970415', 'VietinBank', 'Ngân hàng TMCP Công thương Việt Nam'),
  VietQrBank('970418', 'BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam'),
  VietQrBank(
    '970405',
    'Agribank',
    'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam',
  ),
  VietQrBank('970407', 'Techcombank', 'Ngân hàng TMCP Kỹ thương Việt Nam'),
  VietQrBank('970422', 'MB', 'Ngân hàng TMCP Quân đội'),
  VietQrBank('970416', 'ACB', 'Ngân hàng TMCP Á Châu'),
  VietQrBank('970432', 'VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng'),
  VietQrBank('970423', 'TPBank', 'Ngân hàng TMCP Tiên Phong'),
  VietQrBank('970403', 'Sacombank', 'Ngân hàng TMCP Sài Gòn Thương Tín'),
  VietQrBank('970437', 'HDBank', 'Ngân hàng TMCP Phát triển TP. Hồ Chí Minh'),
  VietQrBank('970441', 'VIB', 'Ngân hàng TMCP Quốc tế Việt Nam'),
  VietQrBank('970443', 'SHB', 'Ngân hàng TMCP Sài Gòn – Hà Nội'),
  VietQrBank('970431', 'Eximbank', 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam'),
  VietQrBank('970426', 'MSB', 'Ngân hàng TMCP Hàng Hải Việt Nam'),
  VietQrBank('970440', 'SeABank', 'Ngân hàng TMCP Đông Nam Á'),
  VietQrBank('970448', 'OCB', 'Ngân hàng TMCP Phương Đông'),
  VietQrBank('970449', 'LPBank', 'Ngân hàng TMCP Lộc Phát Việt Nam'),
  VietQrBank('970428', 'Nam A Bank', 'Ngân hàng TMCP Nam Á'),
  VietQrBank('970409', 'Bac A Bank', 'Ngân hàng TMCP Bắc Á'),
  VietQrBank('970425', 'ABBANK', 'Ngân hàng TMCP An Bình'),
  VietQrBank('970454', 'Ban Viet', 'Ngân hàng TMCP Bản Việt'),
  VietQrBank('970452', 'KienlongBank', 'Ngân hàng TMCP Kiên Long'),
  VietQrBank('970412', 'PVcomBank', 'Ngân hàng TMCP Đại Chúng Việt Nam'),
  VietQrBank('970427', 'VietABank', 'Ngân hàng TMCP Việt Á'),
  VietQrBank('970438', 'BaoViet Bank', 'Ngân hàng TMCP Bảo Việt'),
  VietQrBank('970419', 'NCB', 'Ngân hàng TMCP Quốc Dân'),
  VietQrBank('970400', 'Saigonbank', 'Ngân hàng TMCP Sài Gòn Công Thương'),
  VietQrBank('970433', 'VietBank', 'Ngân hàng TMCP Việt Nam Thương Tín'),
];

VietQrBank? bankByBin(String bin) {
  for (final bank in vietQrBanks) {
    if (bank.bin == bin.trim()) return bank;
  }
  return null;
}

/// Case/diacritic-insensitive matching so "vietcom" or "cong thuong" works.
String _fold(String value) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}
