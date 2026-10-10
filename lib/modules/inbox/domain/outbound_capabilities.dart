// Nguồn: omni-flow-api/modules/Channels/Domain/Support/OutboundCapabilities.php
// (nhánh feat/hop-thu-mobile). Khoá `outbound_capabilities` trên MỌI hội thoại.

/// Kênh gửi đi một loại nội dung theo cách nào.
enum OutboundMode {
  /// Tệp thật trên nền tảng.
  native,

  /// Chỉ vài loại tài liệu nhỏ thành tệp thật, còn lại thành link (Zalo OA).
  docsOnly,

  /// Đường link chèn vào tin chữ, khách bấm để tải.
  link,

  /// Không gửi được.
  none;

  /// Giá trị lạ hoặc thiếu → [none]: không đoán là gửi được.
  static OutboundMode parse(Object? value) => switch (value) {
    'native' => OutboundMode.native,
    'docs_only' => OutboundMode.docsOnly,
    'link' => OutboundMode.link,
    _ => OutboundMode.none,
  };
}

/// Luật tệp nào gửi thành TỆP THẬT khi `file` là [OutboundMode.docsOnly]
/// (`file_constraints: {native_extensions, native_max_bytes}`).
class FileConstraints {
  const FileConstraints({
    required this.nativeExtensions,
    required this.nativeMaxBytes,
  });

  /// Không phải Map → null.
  static FileConstraints? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ext = raw['native_extensions'];
    final max = raw['native_max_bytes'];
    return FileConstraints(
      nativeExtensions: ext is List
          ? ext
                .map((e) => '$e'.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toList()
          : const [],
      nativeMaxBytes: max is num ? max.toInt() : int.tryParse('$max'),
    );
  }

  /// Luật Zalo OA khi API chưa gửi `file_constraints`
  /// (`ZaloConnector::send`: PDF/DOC/DOCX/CSV ≤ 5MB).
  static const zaloOaFallback = FileConstraints(
    nativeExtensions: ['pdf', 'doc', 'docx', 'csv'],
    nativeMaxBytes: 5 * 1024 * 1024,
  );

  /// Đuôi thường, không dấu chấm.
  final List<String> nativeExtensions;

  /// Null = không giới hạn riêng (vẫn chịu trần tải lên chung).
  final int? nativeMaxBytes;

  bool allows(String fileName, int bytes) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (!nativeExtensions.contains(ext)) return false;
    final max = nativeMaxBytes;
    return max == null || bytes <= max;
  }
}

/// Kênh của hội thoại gửi đi được gì. Null trên [Conversation] nghĩa là API cũ
/// chưa có khoá — chỗ dùng giữ hành vi cũ (chữ + ảnh) và ẩn Tệp/Ghi âm.
class OutboundCapabilities {
  const OutboundCapabilities({
    required this.canSend,
    required this.text,
    required this.image,
    required this.file,
    required this.audio,
    required this.video,
    this.fileConstraints,
  });

  /// Không phải Map → null (không đoán).
  static OutboundCapabilities? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final canSend = raw['can_send'];
    return OutboundCapabilities(
      canSend: canSend == true || canSend == 1 || canSend == 'true',
      text: OutboundMode.parse(raw['text']),
      image: OutboundMode.parse(raw['image']),
      file: OutboundMode.parse(raw['file']),
      audio: OutboundMode.parse(raw['audio']),
      video: OutboundMode.parse(raw['video']),
      fileConstraints: FileConstraints.fromJson(raw['file_constraints']),
    );
  }

  final bool canSend;
  final OutboundMode text;
  final OutboundMode image;
  final OutboundMode file;
  final OutboundMode audio;
  final OutboundMode video;

  /// Chỉ có ý nghĩa khi [file] là [OutboundMode.docsOnly].
  final FileConstraints? fileConstraints;

  bool get canSendText => canSend && text != OutboundMode.none;
  bool get canSendImages => canSendText && image != OutboundMode.none;
  bool get canSendFiles => canSendText && file != OutboundMode.none;
  bool get canSendVoice => canSendText && audio != OutboundMode.none;

  /// Tệp [fileName] nặng [bytes] có tới khách thành TỆP THẬT không (false = sẽ
  /// thành đường link, app cần báo trước).
  bool sendsFileNatively(String fileName, int bytes) => switch (file) {
    OutboundMode.native => true,
    OutboundMode.docsOnly =>
      (fileConstraints ?? FileConstraints.zaloOaFallback).allows(
        fileName,
        bytes,
      ),
    OutboundMode.link || OutboundMode.none => false,
  };
}
