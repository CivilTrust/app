import '../../core/models/identity_evidence.dart';
import '../../core/formatting/display_formatters.dart';
import 'contract_template.dart';

class ContractTemplateService {
  static const deposit = ContractTemplate(
    id: 'deposit-v1',
    kind: ContractKind.deposit,
    title: 'Hợp đồng đặt cọc',
    subtitle: 'A nhận cọc · B đặt cọc cho thuê nhà, đồ cũ hoặc tài sản',
    sourceFile: 'Hop-dong-thue-nha-lam-tam-tru.docx',
    iconName: 'verified_user',
    fields: [
      ContractFieldSpec(
        key: 'assetType',
        label: 'Loại giao dịch',
        initialValue: 'Đặt cọc thuê nhà',
      ),
      ContractFieldSpec(
        key: 'assetDescription',
        label: 'Tài sản hoặc đối tượng đặt cọc',
        hint: 'Ví dụ: phòng trọ số 302 hoặc xe máy Honda Wave',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'assetAddress',
        label: 'Địa chỉ hoặc nơi giao nhận tài sản',
      ),
      ContractFieldSpec(
        key: 'totalValue',
        label: 'Tổng giá trị giao dịch (VND)',
        numeric: true,
      ),
      ContractFieldSpec(
        key: 'depositAmount',
        label: 'Số tiền đặt cọc (VND)',
        numeric: true,
      ),
      ContractFieldSpec(
        key: 'completionDate',
        label: 'Hạn ký hợp đồng chính hoặc giao nhận',
        hint: 'dd/mm/yyyy',
      ),
      ContractFieldSpec(
        key: 'breachTerms',
        label: 'Xử lý khi vi phạm đặt cọc',
        initialValue: 'Bên đặt cọc từ chối giao kết thì mất tiền cọc; bên nhận cọc từ chối giao kết thì hoàn trả tiền cọc và một khoản tương đương tiền cọc.',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'additionalTerms',
        label: 'Thỏa thuận bổ sung',
        required: false,
        multiline: true,
      ),
    ],
  );

  static const loan = ContractTemplate(
    id: 'loan-v1',
    kind: ContractKind.loan,
    title: 'Hợp đồng vay tiền',
    subtitle: 'B cho A vay · ghi nhận giải ngân, lãi suất và hạn hoàn trả',
    sourceFile: 'hop-dong-vay-tien_1009151044_2311232834.doc',
    iconName: 'payments',
    fields: [
      ContractFieldSpec(
        key: 'loanPurpose',
        label: 'Mục đích vay',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'principalAmount',
        label: 'Số tiền vay (VND)',
        numeric: true,
      ),
      ContractFieldSpec(
        key: 'disbursementDate',
        label: 'Ngày giải ngân',
        hint: 'dd/mm/yyyy',
      ),
      ContractFieldSpec(
        key: 'dueDate',
        label: 'Ngày đến hạn trả',
        hint: 'dd/mm/yyyy',
      ),
      ContractFieldSpec(
        key: 'interestRate',
        label: 'Lãi suất (%/năm)',
        numeric: true,
        initialValue: '0',
      ),
      ContractFieldSpec(
        key: 'repaymentMethod',
        label: 'Phương thức trả nợ',
        initialValue: 'Thanh toán một lần khi đến hạn',
      ),
      ContractFieldSpec(
        key: 'latePaymentTerms',
        label: 'Xử lý chậm trả',
        initialValue: 'Lãi chậm trả được xác định theo thỏa thuận và trong giới hạn pháp luật tại thời điểm phát sinh.',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'additionalTerms',
        label: 'Thỏa thuận bổ sung',
        required: false,
        multiline: true,
      ),
    ],
  );

  static const templates = [deposit, loan];

  ContractTemplate byId(String id) =>
      templates.firstWhere((template) => template.id == id);

  int amountFor(ContractTemplate template, Map<String, String> fields) {
    final key = template.kind == ContractKind.deposit
        ? 'depositAmount'
        : 'principalAmount';
    return _parseMoney(fields[key]);
  }

  String renderReview({
    required ContractTemplate template,
    required Map<String, String> fields,
    required IdentityEvidence partyA,
  }) {
    final a = partyA.attributes;
    final partyALabel = template.kind == ContractKind.deposit
        ? 'BÊN A (BÊN NHẬN ĐẶT CỌC)'
        : 'BÊN A (BÊN VAY)';
    final identity =
        '$partyALabel: ${a['fullName'] ?? partyA.displayName}, '
        'CCCD ${a['documentNumber'] ?? partyA.documentNumberMasked}, '
        'sinh ngày ${a['dateOfBirth'] ?? 'chưa có'}, '
        'địa chỉ ${a['permanentAddress'] ?? 'chưa có'}.';
    if (template.kind == ContractKind.deposit) {
      return '''$identity

BÊN B (BÊN ĐẶT CỌC): Thông tin định danh được ghi tại khối chữ ký sau khi Bên B xác minh CCCD.

ĐIỀU 1. ĐỐI TƯỢNG ĐẶT CỌC
${fields['assetType']}: ${fields['assetDescription']}.
Địa chỉ hoặc nơi giao nhận: ${fields['assetAddress']}.

ĐIỀU 2. GIÁ TRỊ VÀ TIỀN ĐẶT CỌC
Tổng giá trị giao dịch: ${DisplayFormatters.vnd(_parseMoney(fields['totalValue']))}.
Tiền đặt cọc: ${DisplayFormatters.vnd(_parseMoney(fields['depositAmount']))}.

ĐIỀU 3. THỜI HẠN
Hai bên hoàn tất giao kết hoặc giao nhận trước ngày ${fields['completionDate']}.

ĐIỀU 4. XỬ LÝ VI PHẠM
${fields['breachTerms']}

ĐIỀU 5. CAM KẾT VÀ GIẢI QUYẾT TRANH CHẤP
Hai bên khai đúng thông tin nhân thân, tự nguyện giao kết và ưu tiên thương lượng khi phát sinh tranh chấp. ${fields['additionalTerms'] ?? ''}''';
    }
    return '''$identity

BÊN B (BÊN CHO VAY): Thông tin định danh được ghi tại khối chữ ký sau khi Bên B xác minh CCCD.

ĐIỀU 1. KHOẢN VAY
Bên B đồng ý cho Bên A vay ${DisplayFormatters.vnd(_parseMoney(fields['principalAmount']))}.
Mục đích vay của Bên A: ${fields['loanPurpose']}.

ĐIỀU 2. GIẢI NGÂN VÀ THỜI HẠN
Ngày Bên B giải ngân cho Bên A: ${fields['disbursementDate']}.
Ngày Bên A phải hoàn trả: ${fields['dueDate']}.

ĐIỀU 3. LÃI SUẤT VÀ THANH TOÁN
Lãi suất: ${fields['interestRate']}%/năm.
Phương thức trả nợ: ${fields['repaymentMethod']}.
${fields['latePaymentTerms']}

ĐIỀU 4. CAM KẾT VÀ GIẢI QUYẾT TRANH CHẤP
Các bên tự nguyện giao nhận tiền, sử dụng tiền đúng mục đích và ưu tiên thương lượng khi phát sinh tranh chấp. ${fields['additionalTerms'] ?? ''}''';
  }

  int _parseMoney(String? value) =>
      int.tryParse(value?.replaceAll(RegExp(r'\D'), '') ?? '') ?? 0;
}
