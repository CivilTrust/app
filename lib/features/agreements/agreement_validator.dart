import 'contract_template.dart';
import '../payment/vietqr_service.dart';

class AgreementValidator {
  const AgreementValidator();

  String? validateField(
    ContractTemplate template,
    ContractFieldSpec field,
    String? rawValue,
  ) {
    final value = rawValue?.trim() ?? '';
    if (field.required && value.isEmpty) return 'Không được để trống';
    if (value.isEmpty) return null;

    if (field.numeric) {
      final parsed = int.tryParse(value);
      if (parsed == null) return 'Chỉ nhập chữ số';
      if (field.key == 'interestRate') {
        if (parsed < 0 || parsed > 100) {
          return 'Nhập lãi suất từ 0 đến 100%/năm';
        }
      } else if (parsed <= 0) {
        return 'Số tiền phải lớn hơn 0';
      } else if (parsed > VietQrService.maxAmount) {
        return 'Số tiền không quá 13 chữ số';
      }
    }

    if (_dateKeys.contains(field.key) && parseDate(value) == null) {
      return 'Nhập ngày hợp lệ theo định dạng dd/mm/yyyy';
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

  String? validateBankBin(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Không được để trống';
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

  static const _dateKeys = {'completionDate', 'disbursementDate', 'dueDate'};

  int _money(String? value) => int.tryParse(value ?? '') ?? 0;
}
