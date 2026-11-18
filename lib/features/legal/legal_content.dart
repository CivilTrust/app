/// Static legal/help content. Statements here must match what the app and
/// app/coordinator actually do; update them together with behaviour changes.
///
/// DRAFT: not yet reviewed by a legal professional. The UI shows this status.
library;

class LegalSection {
  const LegalSection(this.heading, this.paragraphs);
  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.version,
    required this.sections,
  });
  final String title;
  final String summary;
  final String version;
  final List<LegalSection> sections;
}

abstract final class LegalInfo {
  static const version = 'Bản dự thảo 0.1 — cập nhật 18/11/2026';
  static const draftNotice =
      'Văn bản đang ở dạng dự thảo cho bản thử nghiệm, chưa được người có '
      'chuyên môn pháp lý rà soát. Không dùng cho giao dịch thật.';

  /// Data controller contact. Empty until the team supplies an official one;
  /// the UI then states that contact details are pending.
  static const controllerName = 'Nhóm phát triển CivilTrust';
  static const contactEmail = '';
}

const termsOfUse = LegalDocument(
  title: 'Điều khoản sử dụng',
  summary:
      'CivilTrust là công cụ kỹ thuật giúp hai bên soạn, khóa nội dung, ký '
      'điện tử và lưu bằng chứng kiểm chứng được. CivilTrust không phải tổ '
      'chức hành nghề công chứng, không chứng thực chữ ký và không phải tổ '
      'chức cung cấp dịch vụ chữ ký số.',
  version: LegalInfo.version,
  sections: [
    LegalSection('1. Phạm vi dịch vụ', [
      'Ứng dụng hỗ trợ: chọn mẫu hợp đồng đặt cọc hoặc vay tiền, điền điều '
          'khoản, khóa nội dung, để mỗi bên ký điện tử trên cùng một nội '
          'dung, tạo VietQR để chuyển khoản và xuất gói bằng chứng (PDF và '
          'tệp kiểm chứng).',
      'Khi được bật, ứng dụng gửi mã băm (hash) của tệp PDF cuối cùng tới '
          'dịch vụ ghi nhận thời điểm và có thể neo mã băm lên blockchain. Mã '
          'băm không chứa nội dung hợp đồng hay thông tin cá nhân.',
    ]),
    LegalSection('2. Bản thử nghiệm và dữ liệu mô phỏng', [
      'Phiên bản hiện tại dùng dữ liệu căn cước mô phỏng và chữ ký điện tử '
          'demo. Ứng dụng chưa đọc hoặc xác thực chip căn cước/CCCD thật.',
      'Không nhập số căn cước, ảnh giấy tờ hoặc tài khoản ngân hàng thật vào '
          'phiên ký thử nghiệm, và không dùng bản thử nghiệm cho giao dịch '
          'thật.',
    ]),
    LegalSection('3. Chữ ký điện tử và giá trị pháp lý', [
      'Chữ ký trong ứng dụng là chữ ký điện tử do thiết bị của từng bên tạo '
          'ra trên nội dung đã khóa. Đây không phải chữ ký số được chứng thực '
          'bởi tổ chức cung cấp dịch vụ chứng thực chữ ký số.',
      'Khi sử dụng, các bên đồng ý dùng phương tiện điện tử để giao kết và '
          'chấp nhận phương thức ký này giữa hai bên. Giá trị pháp lý của hợp '
          'đồng do pháp luật Việt Nam (Bộ luật Dân sự 2015, Luật Giao dịch '
          'điện tử 2023) và cơ quan có thẩm quyền xác định khi có tranh chấp.',
    ]),
    LegalSection('4. Trách nhiệm của người dùng', [
      'Người ký phải đủ 18 tuổi và có năng lực hành vi dân sự đầy đủ, tự '
          'nguyện giao kết và cung cấp thông tin trung thực.',
      'Người dùng tự chịu trách nhiệm về tính hợp pháp của nội dung hợp '
          'đồng, bao gồm lãi suất, tiền cọc và các điều khoản bổ sung. Ứng '
          'dụng chỉ kiểm tra một số giới hạn cơ bản, không thay thế tư vấn '
          'pháp lý.',
      'Người dùng tự giữ mật khẩu kho hợp đồng và gói khôi phục. Mật khẩu '
          'không thể lấy lại; mất mật khẩu đồng nghĩa mất quyền mở kho trên '
          'thiết bị.',
      'Link mời ký là quyền truy cập vào hợp đồng. Chỉ gửi cho đúng bên còn '
          'lại qua kênh tin cậy.',
    ]),
    LegalSection('5. Thanh toán', [
      'Việc chuyển tiền diễn ra ngoài ứng dụng, qua ngân hàng của người '
          'dùng. Ứng dụng không giữ tiền, không kết nối ngân hàng và không tự '
          'xác nhận tiền đã đến.',
      'Mục "đã chuyển" là thông báo của bên chuyển; mục "đã nhận" là xác '
          'nhận của bên nhận sau khi tự kiểm tra tài khoản. Chứng từ đính kèm '
          'không được ứng dụng kiểm tra tính xác thực.',
    ]),
    LegalSection('6. Giới hạn trách nhiệm', [
      'Ứng dụng được cung cấp ở dạng thử nghiệm phục vụ học tập và nghiên '
          'cứu. Dịch vụ có thể gián đoạn; dữ liệu trên máy chủ điều phối tự '
          'hết hạn theo Chính sách quyền riêng tư. Hãy tải và lưu gói bằng '
          'chứng của mình.',
    ]),
    LegalSection('7. Luật áp dụng và thay đổi điều khoản', [
      'Điều khoản này được điều chỉnh bởi pháp luật Việt Nam. Khi điều khoản '
          'thay đổi, phiên bản và ngày cập nhật ở đầu trang sẽ thay đổi; hợp '
          'đồng đã ký không bị sửa theo.',
    ]),
  ],
);

const privacyPolicy = LegalDocument(
  title: 'Chính sách quyền riêng tư',
  summary:
      'Dữ liệu hợp đồng được mã hóa trên thiết bị của bạn. Máy chủ điều phối '
      'chỉ giữ bản mã hóa mà máy chủ không đọc được; dịch vụ ghi nhận thời '
      'điểm chỉ nhận mã băm của tệp PDF. Chính sách được xây dựng theo Luật '
      'Bảo vệ dữ liệu cá nhân 2025 (Luật số 91/2025/QH15).',
  version: LegalInfo.version,
  sections: [
    LegalSection('1. Dữ liệu được xử lý', [
      'Thông tin định danh của các bên: họ tên, ngày sinh, số căn cước, '
          'ngày/nơi cấp, địa chỉ. Trong bản thử nghiệm đây là dữ liệu mô '
          'phỏng.',
      'Nội dung hợp đồng: tài sản, số tiền, thời hạn, điều khoản.',
      'Thông tin nhận tiền: ngân hàng, số tài khoản, tên chủ tài khoản.',
      'Chứng từ chuyển khoản nếu bạn tự đính kèm (ảnh PNG/JPEG hoặc PDF, tối '
          'đa 1 MiB).',
      'Khóa và chữ ký điện tử do thiết bị tạo cho từng lần ký.',
    ]),
    LegalSection('2. Mục đích', [
      'Lập, ký và lưu hợp đồng giữa đúng hai bên; tạo VietQR chuyển khoản; '
          'tạo gói bằng chứng để các bên hoặc bên thứ ba kiểm chứng. Không '
          'dùng cho quảng cáo, không bán dữ liệu, ứng dụng không cài công cụ '
          'phân tích hành vi.',
    ]),
    LegalSection('3. Nơi lưu và thời hạn', [
      'Trên thiết bị: kho hợp đồng mã hóa AES-256-GCM bằng mật khẩu chỉ bạn '
          'biết. Dữ liệu còn đến khi bạn xóa kho hoặc xóa dữ liệu trang web.',
      'Máy chủ điều phối: chỉ lưu bản đã mã hóa để hai bên đồng bộ. Khóa giải '
          'mã nằm trong link mời, không gửi lên máy chủ. Phiên đang xử lý tự '
          'xóa sau 7 ngày; hồ sơ đã hoàn tất được giữ để tải lại trong 30 '
          'ngày rồi tự xóa. Máy chủ không ghi nhật ký nội dung yêu cầu.',
      'Dịch vụ ghi nhận thời điểm (khi được bật): chỉ nhận mã băm 32 byte '
          'của tệp PDF cuối. Mã băm có thể được gom và neo lên blockchain; dữ '
          'liệu này công khai, vĩnh viễn và không thể xóa, nhưng không chứa '
          'thông tin cá nhân hay nội dung hợp đồng.',
    ]),
    LegalSection('4. Ai thấy dữ liệu của bạn', [
      'Bên còn lại của hợp đồng thấy toàn bộ nội dung, thông tin định danh '
          'và thông tin nhận tiền để kiểm tra trước khi ký.',
      'Gói bằng chứng (ZIP) bạn tải về chứa thông tin cá nhân của hai bên. '
          'Người nhận gói đó sẽ đọc được; chỉ chia sẻ khi cần.',
    ]),
    LegalSection('5. Quyền của bạn', [
      'Bạn có quyền được biết, đồng ý hoặc không đồng ý, rút lại sự đồng ý, '
          'xem, chỉnh sửa và yêu cầu xóa dữ liệu theo Luật Bảo vệ dữ liệu cá '
          'nhân 2025.',
      'Bạn có thể từ chối đọc danh tính; khi đó không thể ký hợp đồng. Bản '
          'nháp chưa gửi có thể sửa hoặc xóa trong kho. Hợp đồng đã ký không '
          'thể sửa để bảo toàn bằng chứng; muốn thay đổi, hai bên lập bản '
          'thay thế.',
      'Rút lại đồng ý không làm mất hiệu lực các xử lý đã thực hiện trước '
          'đó, và không xóa được mã băm đã neo trên blockchain.',
    ]),
    LegalSection('6. Bảo mật', [
      'Mã hóa đầu cuối giữa hai thiết bị, kho cục bộ có mật khẩu, khóa kho '
          'khi ứng dụng chuyển sang nền. Không có hệ thống nào an toàn tuyệt '
          'đối; hãy dùng mật khẩu mạnh và giữ link mời riêng tư.',
    ]),
    LegalSection('7. Liên hệ', [
      'Bên kiểm soát dữ liệu: ${LegalInfo.controllerName}. Thông tin liên hệ '
          'chính thức sẽ được công bố trước khi phát hành bản chính thức.',
    ]),
  ],
);

class FaqItem {
  const FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

const faqItems = [
  FaqItem(
    'CivilTrust có phải công chứng không?',
    'Không. CivilTrust giúp hai bên ký điện tử trên cùng một nội dung và lưu '
        'bằng chứng kiểm chứng được. Hợp đồng không được công chứng hay chứng '
        'thực bởi cơ quan nhà nước.',
  ),
  FaqItem(
    'Hai bên ở xa nhau có ký được không?',
    'Được. Một bên tạo hợp đồng và gửi link mời riêng; bên còn lại mở link '
        'trên điện thoại hoặc máy tính, đọc, xác minh danh tính và ký.',
  ),
  FaqItem(
    'Ai chuyển tiền cho ai?',
    'Bên B chuyển cho Bên A: bên đặt cọc chuyển cho bên nhận cọc, bên cho vay '
        'giải ngân cho bên vay. Ứng dụng tạo VietQR với đúng số tiền và nội '
        'dung chuyển khoản.',
  ),
  FaqItem(
    'Ứng dụng có biết tiền đã đến chưa?',
    'Không. Bên nhận phải tự kiểm tra trong app ngân hàng rồi mới bấm xác nhận '
        'đã nhận tiền.',
  ),
  FaqItem(
    'Sửa hợp đồng sau khi ký được không?',
    'Không. Nội dung đã khóa và ký thì giữ nguyên để làm bằng chứng. Muốn thay '
        'đổi, hai bên lập một đề xuất thay thế và ký lại.',
  ),
  FaqItem(
    'Quên mật khẩu kho thì sao?',
    'Không thể khôi phục mật khẩu. Hãy xuất gói khôi phục mã hóa và giữ mật '
        'khẩu ở nơi an toàn ngay sau khi tạo kho.',
  ),
  FaqItem(
    'Tại sao cần đọc căn cước?',
    'Để ghi đúng thông tin các bên vào hợp đồng. Bản thử nghiệm dùng dữ liệu '
        'mô phỏng; đọc chip căn cước bằng NFC sẽ có ở bản iPhone sau.',
  ),
  FaqItem(
    'Người khác kiểm chứng hợp đồng thế nào?',
    'Mở mục Kiểm chứng và chọn tệp ZIP. Ứng dụng tính lại mã băm, kiểm chữ ký '
        'của hai bên và biên nhận thời điểm ngay trên trình duyệt, không tải '
        'tệp lên máy chủ.',
  ),
];
