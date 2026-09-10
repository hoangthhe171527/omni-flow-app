import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';

/// Dòng thời gian chỉ có ích khi nó nói được AI VỪA LÀM GÌ.
///
/// Bản đầu đọc năm trong chín loại `TaskActivityService` ghi, nên bốn loại còn
/// lại rơi hết về "đã có thay đổi" — trong đó có `subtask_completed` và
/// `attachment_added`, tức tick xong một việc con và gửi ảnh: hai việc thợ
/// làm nhiều nhất trong ngày. Số dòng vẫn đúng, nội dung thì rỗng.
void main() {
  FeedEntry of(String type, [Map<String, dynamic> extra = const {}]) =>
      FeedEntry.fromJson({
        'id': 'a1',
        'type': type,
        'task_id': 't1',
        'task_title': 'KAWAI HAT-5 — SN 2308512',
        'created_at': '2026-09-07T08:00:00Z',
        'user_name': 'Hằng Ni',
        ...extra,
      });

  group('mọi loại API ghi đều đọc ra được', () {
    // Danh sách này là hợp đồng với TaskActivityService. Thêm loại bên API mà
    // quên ở đây thì dòng đó hiện "đã có thay đổi" — im lặng, không lỗi.
    const written = {
      'created': FeedKind.created,
      'status': FeedKind.status,
      'section_id': FeedKind.section,
      'due_date': FeedKind.dueDate,
      'assignees': FeedKind.assignees,
      'subtask_completed': FeedKind.subtaskCompleted,
      'subtask_assigned': FeedKind.subtaskAssigned,
      'attachment_added': FeedKind.attachmentAdded,
      'attachment_removed': FeedKind.attachmentRemoved,
    };

    for (final entry in written.entries) {
      test('${entry.key} không rơi về other', () {
        expect(FeedKind.parse(entry.key), entry.value);
      });
    }

    test('không loại nào đọc ra câu vô nghĩa', () {
      for (final type in written.keys) {
        expect(
          of(type).summary,
          isNot('đã có thay đổi'),
          reason: '$type là loại API THẬT SỰ ghi — nó phải nói được nội dung.',
        );
      }
    });
  });

  group('tick xong việc con', () {
    test('gọi thẳng tên việc con', () {
      // "đã xong Body ngoài" đọc lướt là hiểu. "đã hoàn thành việc con" thì
      // phải mở cây đàn ra mới biết việc con nào.
      final entry = of('subtask_completed', {'title': 'Body ngoài'});

      expect(entry.summary, 'đã xong Body ngoài');
    });

    test('thiếu tên thì vẫn nói được là việc con nào đó xong', () {
      expect(of('subtask_completed').summary, 'đã xong một việc con');
      expect(
        of('subtask_completed', {'title': ''}).summary,
        'đã xong một việc con',
      );
    });
  });

  group('đính kèm', () {
    test('nói rõ tệp gì — ảnh là bằng chứng của §B2', () {
      final entry = of('attachment_added', {'name': 'body-sau.jpg'});

      expect(entry.summary, 'đã gửi body-sau.jpg');
    });

    test('thiếu tên tệp vẫn thành câu', () {
      expect(of('attachment_added').summary, 'đã gửi tệp đính kèm');
    });

    test('gỡ đính kèm khác với thêm', () {
      expect(of('attachment_removed').summary, 'đã gỡ tệp đính kèm');
    });
  });

  group('loại lạ', () {
    test('vẫn hiện, không bị giấu', () {
      // Client cũ gặp loại mới phải nói "có thay đổi" chứ không được bỏ dòng.
      final entry = of('mot_loai_moi_nao_do');

      expect(entry.kind, FeedKind.other);
      expect(entry.summary, 'đã có thay đổi');
    });
  });

  group('hai khoá cho cùng một vai trò', () {
    test('title cho việc con, name cho tệp — đọc được cả hai', () {
      expect(of('subtask_completed', {'title': 'Lên dây'}).detail, 'Lên dây');
      expect(of('attachment_added', {'name': 'truoc.png'}).detail, 'truoc.png');
    });
  });

  group('ảnh đại diện người làm', () {
    test('đọc user_avatar khi server gửi', () {
      // Server giải sẵn (PeopleDirectory) — client không tự tra id ra ảnh,
      // cùng lập luận với `user_name`.
      final entry = of('subtask_completed', {
        'user_avatar': 'https://api.test/api/v1/auth/avatar/abc.png',
      });

      expect(entry.userAvatar, 'https://api.test/api/v1/auth/avatar/abc.png');
    });

    test('người chưa đặt ảnh thì null, không phải chuỗi rỗng', () {
      // Chuỗi rỗng sẽ thành một thẻ ảnh trỏ vào hư không; null thì OmniAvatar
      // rơi về chữ cái đầu.
      expect(of('subtask_completed').userAvatar, isNull);
    });
  });

  group('dữ liệu ảnh hai thời kỳ', () {
    // Server từng để loại TỆP ghi đè loại HOẠT ĐỘNG, nên những dòng ghi trước
    // bản sửa nằm trong Mongo với `type: 'image'`. Không backfill — đọc được
    // cả hai ở đây rẻ hơn một migration, và không có cửa sổ nào dữ liệu hiện
    // sai.
    test('dạng mới: type là hoạt động, file_type là tệp', () {
      final entry = of('attachment_added', {
        'file_type': 'image',
        'name': 'body-ngoai.jpg',
        'url': '/api/v1/tasks/media/abc.jpg',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.summary, 'đã gửi body-ngoai.jpg');
      expect(entry.imageUrl, '/api/v1/tasks/media/abc.jpg');
    });

    test('dạng cũ: type bị loại tệp ghi đè mất', () {
      final entry = of('image', {
        'name': 'lung-dan.jpg',
        'url': '/api/v1/tasks/media/def.jpg',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.summary, 'đã gửi lung-dan.jpg');
      expect(entry.imageUrl, '/api/v1/tasks/media/def.jpg');
    });

    test('dạng cũ, tệp không phải ảnh', () {
      final entry = of('file', {
        'name': 'bao-gia.pdf',
        'url': '/api/v1/tasks/media/ghi.pdf',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.imageUrl, isNull);
    });

    test('dạng mới, tệp không phải ảnh thì không có thumbnail', () {
      // Một PDF render ra ô vỡ giữa dòng chữ thì tệ hơn là không render gì.
      final entry = of('attachment_added', {
        'file_type': 'file',
        'name': 'bao-gia.pdf',
        'url': '/api/v1/tasks/media/ghi.pdf',
      });

      expect(entry.imageUrl, isNull);
    });
  });
}
