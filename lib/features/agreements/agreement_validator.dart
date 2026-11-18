import 'contract_template.dart';
import '../payment/vietqr_service.dart';

/// Form-level rules for new drafts. These checks run before a draft is frozen;
/// they never re-judge already signed records, whose digest is authoritative.
class AgreementValidator {
  const AgreementValidator({this.clock});

  /// Injectable for tests; defaults to the device clock.
  final DateTime Function()? clock;

  /// Bộ luật Dân sự 2015, Điều 468: agreed interest may not exceed 20%/year
  /// unless another law provides otherwise.
  static const maxInterestPercent = 20.0;
  static const adultAge = 18;
  static const _maxDateYears = {
    'completionDate': 5,
    'disbursementDate': 1,
    'dueDate': 30,
  };

  DateTime get _today {
    final now = (clock ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  /// Earliest/latest selectable day for a date field (used by date pickers).
  (DateTime, DateTime) dateBounds(String key) {
    final today = _today;
    final years = _maxDateYears[key] ?? 5;
    return (today, DateTime(today.year + years, today.month, today.day));
  }

  String? validateField(
    ContractTemplate template,
    ContractFieldSpec field,
    String? rawValue,
  ) {
    final value = rawValue?.trim() ?? '';
    if (field.required && value.isEmpty) return 'Không được để trống';
    if (value.isEmpty) return null;

    switch (field.kind) {
      case FieldKind.money:
        final digits = value.replaceAll('.', '');
        final parsed = RegExp(r'^\d+$').hasMatch(digits)
            ? int.tryParse(digits)
            : null;
        if (parsed == null) return 'Chỉ nhập chữ số';
        if (parsed <= 0) return 'Số tiền phải lớn hơn 0';
        if (parsed > VietQrService.maxAmount) {
          return 'Số tiền không quá 13 chữ số';
        }
        if (parsed < 1000) return 'Số tiền tối thiểu là 1.000 đồng';
      case FieldKind.percent:
        final rate = parsePercent(value);
        if (rate == null) return 'Nhập số, tối đa 2 chữ số thập phân';
        if (rate < 0 || rate > maxInterestPercent) {
          return 'Lãi suất từ 0 đến 20%/năm (Điều 468 BLDS 2015)';
        }
      case FieldKind.date:
        final date = parseDate(value);
        if (date == null) return 'Nhập ngày hợp lệ theo định dạng dd/mm/yyyy';
        final (first, last) = dateBounds(field.key);
        if (date.isBefore(first)) return 'Ngày không được trước hôm nay';
        if (date.isAfter(last)) {
          return 'Ngày quá xa (tối đa ${_maxDateYears[field.key] ?? 5} năm)';
        }
      case FieldKind.text:
        if (RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]')
            .hasMatch(value)) {
          return 'Có ký tự không hợp lệ';
        }
        if (value.length < field.minLength) {
          return 'Nhập ít nhất ${field.minLength} ký tự';
        }
        if (value.length > field.maxLength) {
          return 'Tối đa ${field.maxLength} ký tự';
        }
    }
    return null;
  }

  String? validateBusinessRules(
    ContractTemplate template,
    Map<String, String> fields,
  ) {
    if (template.kind == ContractKind.deposit) {
      final total = _money(fields['totalValue']);
      final deposit = _money(fields['depositAmount']);
      if (deposit > total) {
        return 'Tiền đặt cọc không được lớn hơn tổng giá trị giao dịch.';
      }
      return null;
    }

    final disbursement = parseDate(fields['disbursementDate'] ?? '');
    final due = parseDate(fields['dueDate'] ?? '');
    if (disbursement != null && due != null && !due.isAfter(disbursement)) {
      return 'Ngày đến hạn phải sau ngày giải ngân.';
    }
    return null;
  }

  /// Returns an explanation when the person is not yet [adultAge] on the
  /// signing day (Bộ luật Dân sự 2015, Điều 20), or null when eligible.
  /// Unknown/unparseable birth dates return null; trusted verification of the
  /// date of birth is the identity verifier's job.
  String? signerAgeError(String? dateOfBirth) {
    final birth = parseDate(dateOfBirth?.trim() ?? '');
    if (birth == null) return null;
    final today = _today;
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age >= adultAge
        ? null
        : 'Người ký phải đủ $adultAge tuổi để tự mình giao kết hợp đồng '
              '(Điều 20 Bộ luật Dân sự 2015).';
  }

  String? validateBankBin(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Chọn ngân hàng nhận tiền';
    return VietQrService.isBankBin(value)
        ? null
        : 'Mã BIN phải gồm đúng 6 chữ số';
  }

  String? validateAccountNumber(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Không được để trống';
    return VietQrService.isAccountNumber(value)
        ? null
        : 'Số tài khoản gồm 4–19 ký tự chữ hoặc số';
  }

  String? validateAccountName(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Không được để trống';
    if (value.length > 70) return 'Tối đa 70 ký tự';
    return RegExp(r"^[\p{L} .'-]+$", unicode: true).hasMatch(value)
        ? null
        : 'Chỉ gồm chữ cái và khoảng trắng';
  }

  double? parsePercent(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }

  DateTime? parseDate(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (year < 1900 || year > 2200) return null;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }

  int _money(String? value) =>
      int.tryParse((value ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;
}
