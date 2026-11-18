import '../../core/models/identity_evidence.dart';
import '../../core/models/party_role.dart';
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
        helper: 'Ví dụ: đặt cọc thuê nhà, mua xe máy, mua đồ cũ.',
        initialValue: 'Đặt cọc thuê nhà',
        minLength: 3,
        maxLength: 120,
      ),
      ContractFieldSpec(
        key: 'assetDescription',
        label: 'Tài sản đặt cọc',
        hint: 'Ví dụ: phòng trọ số 302, nhà số 5 ngõ 10…',
        helper:
            'Mô tả đủ để nhận diện tài sản: loại, đặc điểm, số hiệu nếu có.',
        multiline: true,
        minLength: 5,
        maxLength: 500,
      ),
      ContractFieldSpec(
        key: 'assetAddress',
        label: 'Nơi giao nhận tài sản',
        helper: 'Địa chỉ của tài sản hoặc nơi hai bên giao nhận.',
        minLength: 5,
      ),
      ContractFieldSpec(
        key: 'totalValue',
        label: 'Tổng giá trị giao dịch',
        helper: 'Giá trị của giao dịch chính mà khoản cọc bảo đảm.',
        kind: FieldKind.money,
      ),
      ContractFieldSpec(
        key: 'depositAmount',
        label: 'Số tiền đặt cọc',
        helper: 'Không vượt quá tổng giá trị giao dịch.',
        kind: FieldKind.money,
      ),
      ContractFieldSpec(
        key: 'completionDate',
        label: 'Hạn hoàn tất giao dịch',
        helper: 'Hạn ký hợp đồng chính hoặc giao nhận tài sản.',
        hint: 'dd/mm/yyyy',
        kind: FieldKind.date,
      ),
      ContractFieldSpec(
        key: 'breachTerms',
        label: 'Xử lý khi vi phạm đặt cọc',
        helper: 'Mặc định theo khoản 2 Điều 328 Bộ luật Dân sự 2015.',
        minLength: 10,
        maxLength: 1000,
        initialValue: 'Bên đặt cọc từ chối giao kết thì mất tiền cọc; bên nhận cọc từ chối giao kết thì hoàn trả tiền cọc và một khoản tương đương tiền cọc.',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'additionalTerms',
        label: 'Thỏa thuận bổ sung',
        helper: 'Không bắt buộc.',
        required: false,
        multiline: true,
        maxLength: 2000,
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
        hint: 'Ví dụ: chi phí học tập, sửa nhà…',
        multiline: true,
        minLength: 3,
        maxLength: 500,
      ),
      ContractFieldSpec(
        key: 'principalAmount',
        label: 'Số tiền vay',
        kind: FieldKind.money,
      ),
      ContractFieldSpec(
        key: 'disbursementDate',
        label: 'Ngày giải ngân',
        helper: 'Ngày Bên B chuyển tiền vay cho Bên A; không sớm hơn hôm nay.',
        hint: 'dd/mm/yyyy',
        kind: FieldKind.date,
      ),
      ContractFieldSpec(
        key: 'dueDate',
        label: 'Ngày đến hạn trả',
        helper: 'Phải sau ngày giải ngân.',
        hint: 'dd/mm/yyyy',
        kind: FieldKind.date,
      ),
      ContractFieldSpec(
        key: 'interestRate',
        label: 'Lãi suất (%/năm)',
        helper: 'Từ 0 đến 20%/năm theo Điều 468 Bộ luật Dân sự 2015; tối đa 2 chữ số thập phân.',
        kind: FieldKind.percent,
        initialValue: '0',
      ),
      ContractFieldSpec(
        key: 'repaymentMethod',
        label: 'Phương thức trả nợ',
        initialValue: 'Thanh toán một lần khi đến hạn',
        minLength: 5,
      ),
      ContractFieldSpec(
        key: 'latePaymentTerms',
        label: 'Xử lý chậm trả',
        minLength: 10,
        maxLength: 1000,
        initialValue: 'Lãi chậm trả được xác định theo thỏa thuận và trong giới hạn pháp luật tại thời điểm phát sinh.',
        multiline: true,
      ),
      ContractFieldSpec(
        key: 'additionalTerms',
        label: 'Thỏa thuận bổ sung',
        helper: 'Không bắt buộc.',
        required: false,
        multiline: true,
        maxLength: 2000,
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
    PartyRole creatorRole = PartyRole.partyA,
  }) {
    final a = partyA.attributes;
    final partyALabel = creatorRole == PartyRole.partyB
        ? (template.kind == ContractKind.deposit
              ? 'BÊN B (BÊN ĐẶT CỌC)'
              : 'BÊN B (BÊN CHO VAY)')
        : template.kind == ContractKind.deposit
        ? 'BÊN A (BÊN NHẬN ĐẶT CỌC)'
        : 'BÊN A (BÊN VAY)';
    final identity =
        '$partyALabel: ${a['fullName'] ?? partyA.displayName}, '
        'CCCD ${a['documentNumber'] ?? partyA.documentNumberMasked}, '
        'sinh ngày ${a['dateOfBirth'] ?? 'chưa có'}, '
        'địa chỉ ${a['permanentAddress'] ?? 'chưa có'}.';
    final counterparty = creatorRole == PartyRole.partyA
        ? (template.kind == ContractKind.deposit
              ? 'BÊN B (BÊN ĐẶT CỌC)'
              : 'BÊN B (BÊN CHO VAY)')
        : (template.kind == ContractKind.deposit
              ? 'BÊN A (BÊN NHẬN ĐẶT CỌC)'
              : 'BÊN A (BÊN VAY)');
    if (template.kind == ContractKind.deposit) {
      return '''$identity

$counterparty: Thông tin định danh được ghi tại khối chữ ký khi bên còn lại ký. Không thay đổi nội dung đã khóa để điền thêm danh tính.

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

$counterparty: Thông tin định danh được ghi tại khối chữ ký khi bên còn lại ký. Không thay đổi nội dung đã khóa để điền thêm danh tính.

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
