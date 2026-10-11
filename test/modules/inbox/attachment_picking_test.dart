import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:omni_app/modules/inbox/domain/pending_attachment.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/attachment_picking.dart';

/// Trình chọn ảnh giả: ghi lại lượt gọi, trả ảnh hoặc ném lỗi nền tảng.
class _FakePicker extends ImagePicker {
  final calls = <String>[];
  int? lastLimit;
  PlatformException? error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add('pickImage:${source.name}');
    if (error != null) throw error!;
    return XFile('/tmp/mot.jpg');
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add('pickMultiImage');
    lastLimit = limit;
    if (error != null) throw error!;
    return [XFile('/tmp/a.jpg'), XFile('/tmp/b.jpg')];
  }
}

void main() {
  late _FakePicker picker;
  setUp(() => picker = _FakePicker());

  test('còn 1 chỗ → pickImage (thư viện), không pickMultiImage', () async {
    final picked = await pickInboxImages(picker, 1, null);
    expect(picker.calls, ['pickImage:gallery']);
    expect(picked.single.kind, PendingKind.image);
    expect(picked.single.path, '/tmp/mot.jpg');
  });

  test('còn ≥ 2 chỗ → pickMultiImage(limit: còn lại)', () async {
    final picked = await pickInboxImages(picker, 4, null);
    expect(picker.calls, ['pickMultiImage']);
    expect(picker.lastLimit, 4);
    expect(picked, hasLength(2));
  });

  test('hết chỗ → không mở trình chọn', () async {
    expect(await pickInboxImages(picker, 0, null), isEmpty);
    expect(picker.calls, isEmpty);
  });

  test('PlatformException (từ chối quyền ảnh) → PickerUnavailable', () async {
    picker.error = PlatformException(code: 'photo_access_denied');
    await expectLater(
      pickInboxImages(picker, 5, null),
      throwsA(
        isA<PickerUnavailable>().having(
          (e) => e.message,
          'message',
          contains('thư viện ảnh'),
        ),
      ),
    );
  });

  test('PlatformException ở máy ảnh → PickerUnavailable', () async {
    picker.error = PlatformException(code: 'camera_access_denied');
    await expectLater(
      takeInboxPhoto(picker, null),
      throwsA(
        isA<PickerUnavailable>().having(
          (e) => e.message,
          'message',
          contains('máy ảnh'),
        ),
      ),
    );
  });

  test('chọn tệp: bỏ tệp không có đường dẫn; lỗi nền tảng → '
      'PickerUnavailable', () async {
    final files = await pickInboxFiles(
      pick: () async => FilePickerResult([
        PlatformFile(name: 'a.pdf', size: 10, path: '/tmp/a.pdf'),
        PlatformFile(name: 'ao.pdf', size: 10),
      ]),
    );
    expect(files.single.name, 'a.pdf');
    expect(files.single.kind, PendingKind.file);
    expect(files.single.size, 10);

    await expectLater(
      pickInboxFiles(
        pick: () async =>
            throw PlatformException(code: 'read_external_storage_denied'),
      ),
      throwsA(isA<PickerUnavailable>()),
    );
  });
}
