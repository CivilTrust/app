import 'sct_verifier.dart';

String sctVerificationLabel(SctVerificationResult result) =>
    switch (result.status) {
      SctVerificationStatus.valid => 'SCT đã tự kiểm chữ ký',
      SctVerificationStatus.invalid => 'SCT không hợp lệ',
      SctVerificationStatus.unsupported => 'SCT chưa được hỗ trợ',
      SctVerificationStatus.notConfigured =>
        'SCT chưa thể kết luận: thiếu cấu hình tin cậy',
    };

String sctVerificationDetail(SctVerificationResult result) =>
    switch (result.status) {
      SctVerificationStatus.valid =>
        'Hash PDF, domain deployment và chữ ký của signer được cấu hình khớp. '
            'Chưa kiểm Merkle proof hoặc blockchain.',
      SctVerificationStatus.invalid =>
        'Không dùng SCT này để khẳng định cam kết. Lý do: ${result.reason}',
      SctVerificationStatus.unsupported =>
        'Client chưa hỗ trợ định dạng SCT này: ${result.reason}',
      SctVerificationStatus.notConfigured =>
        'Đã phục hồi chữ ký, nhưng chưa có địa chỉ contract và signer tin cậy '
            'của deployment để đối chiếu.',
    };
