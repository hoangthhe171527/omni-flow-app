import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Ghi âm cho composer Hộp thư. Composer chỉ nói chuyện với giao diện này,
/// không gọi plugin trực tiếp — test widget thay bằng bản giả.
abstract interface class VoiceRecorder {
  /// Xin quyền micro (hỏi hệ điều hành nếu chưa hỏi). False = bị từ chối.
  Future<bool> ensurePermission();

  /// Đường dẫn tệp mới trong thư mục tạm, tên theo [voiceRecordingName].
  Future<String> newRecordingPath();

  /// Bắt đầu ghi vào [path]: WAV PCM 16-bit, 16 kHz, mono.
  Future<void> start(String path);

  /// Dừng và trả đường dẫn tệp; null nếu lỗi.
  Future<String?> stop();

  /// Dừng (nếu đang ghi) và xoá tệp của lượt ghi gần nhất.
  Future<void> cancel();

  /// Xoá tệp [path] của một bản ghi đã dừng (vd đã gửi xong). Không có tệp
  /// thì thôi.
  Future<void> discard(String path);

  /// Thời gian đã ghi, nhịp 200ms, bắt đầu từ 0 mỗi lần [start].
  Stream<Duration> get elapsed;

  Future<void> dispose();
}

/// `ghi-am-yyyyMMdd-HHmmss.wav` — tên khách thấy khi kênh gửi thành đường link.
String voiceRecordingName(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'ghi-am-${at.year}${two(at.month)}${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}${two(at.second)}.wav';
}

/// Cấu hình ghi. WAV chứ không AAC/m4a: `POST /inbox/media` kiểm MIME dò từ
/// nội dung (`config/media.php`), mà libmagic dò `.m4a` của iOS ra
/// `audio/x-m4a` (không được phép → 422) và của Android ra `video/mp4` (lọt,
/// nhưng server xếp thành `video`). WAV dò ra `audio/x-wav` trên cả hai.
/// 16 kHz mono ≈ 1,9MB/phút; 5 phút ≈ 9,6MB, dưới trần 25MB.
const kVoiceRecordConfig = RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
);

/// Bản thật trên gói `record` (Android: `RECORD_AUDIO` trong manifest; iOS:
/// `NSMicrophoneUsageDescription` trong Info.plist).
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({AudioRecorder? recorder}) : _made = recorder;

  // Tạo lười: mở trang hội thoại không đụng kênh nền tảng cho tới lần bấm
  // mic đầu tiên (và test widget không cần plugin).
  AudioRecorder? _made;
  AudioRecorder get _recorder => _made ??= AudioRecorder();
  final _ticks = StreamController<Duration>.broadcast();
  final _clock = Stopwatch();
  Timer? _timer;
  String? _path;
  bool _recording = false;

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  @override
  Future<String> newRecordingPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}${Platform.pathSeparator}'
        '${voiceRecordingName(DateTime.now())}';
  }

  @override
  Future<void> start(String path) async {
    await _recorder.start(kVoiceRecordConfig, path: path);
    _path = path;
    _recording = true;
    _clock
      ..reset()
      ..start();
    _ticks.add(Duration.zero);
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _ticks.add(_clock.elapsed),
    );
  }

  void _halt() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _recording = false;
  }

  @override
  Future<String?> stop() async {
    _halt();
    try {
      return await _recorder.stop() ?? _path;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    final wasRecording = _recording;
    _halt();
    if (wasRecording) {
      try {
        await _recorder.cancel();
      } on Object {
        // vẫn xoá tệp bên dưới
      }
    }
    final path = _path;
    _path = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // Thư mục tạm: hệ điều hành dọn sau.
    }
  }

  @override
  Future<void> discard(String path) async {
    if (_path == path) _path = null;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Stream<Duration> get elapsed => _ticks.stream;

  @override
  Future<void> dispose() async {
    if (_recording) await cancel();
    _halt();
    await _ticks.close();
    await _made?.dispose();
  }
}

/// Một máy ghi cho mỗi trang hội thoại đang mở; rời trang thì giải phóng.
final voiceRecorderProvider = Provider.autoDispose<VoiceRecorder>((ref) {
  final recorder = RecordVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
