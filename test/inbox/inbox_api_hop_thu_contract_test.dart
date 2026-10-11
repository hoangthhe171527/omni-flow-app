import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_permissions.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

import '../support/fake_http_adapter.dart';

/// Hợp đồng Hộp thư mobile — đối chiếu `omni-flow-api` nhánh
/// `feat/hop-thu-mobile` (routes.php, InboxController, InboxDTO::forViewer,
/// MessageDTO, OutboundCapabilities). Mỗi khoá một khẳng định: đây là kiểu
/// lỗi client↔server im lặng của dự án.
void main() {
  (InboxApi, FakeAdapter) api(Object data, {int status = 200, String? raw}) {
    final adapter = FakeAdapter(status, raw ?? envelope(data));
    return (InboxApi(ApiClient(Dio()..httpClientAdapter = adapter)), adapter);
  }

  group('hội thoại: khoá theo người xem + khả năng gửi', () {
    final json = {
      'id': 'c1',
      'channel': 'zalo',
      'status': 'open',
      'is_pinned': true,
      'is_muted': true,
      'blocked_at': '2026-10-10T03:00:00.000Z',
      'blocked_by': 'u9',
      'outbound_capabilities': {
        'can_send': true,
        'text': 'native',
        'image': 'native',
        'file': 'docs_only',
        'audio': 'link',
        'video': 'link',
        'file_constraints': {
          'native_extensions': ['pdf', 'doc', 'docx', 'csv'],
          'native_max_bytes': 5242880,
        },
      },
    };

    test('đọc is_pinned / is_muted / blocked_at / outbound_capabilities', () {
      final c = Conversation.fromJson(json);
      expect(c.isPinned, isTrue);
      expect(c.isMuted, isTrue);
      expect(c.isBlocked, isTrue);
      expect(c.blockedAt, DateTime.utc(2026, 10, 10, 3));
      final cap = c.outboundCapabilities!;
      expect(cap.canSend, isTrue);
      expect(cap.text, OutboundMode.native);
      expect(cap.image, OutboundMode.native);
      expect(cap.file, OutboundMode.docsOnly);
      expect(cap.audio, OutboundMode.link);
      expect(cap.video, OutboundMode.link);
      expect(cap.canSendText, isTrue);
      expect(cap.canSendImages, isTrue);
      expect(cap.canSendFiles, isTrue);
      expect(cap.canSendVoice, isTrue);
    });

    test('file_constraints (Zalo OA): đuôi + trần byte gửi thành tệp thật', () {
      final cap = Conversation.fromJson(json).outboundCapabilities!;
      final fc = cap.fileConstraints!;
      expect(fc.nativeExtensions, ['pdf', 'doc', 'docx', 'csv']);
      expect(fc.nativeMaxBytes, 5242880);
      expect(cap.sendsFileNatively('Bao-gia.PDF', 1024), isTrue);
      expect(cap.sendsFileNatively('bang.xlsx', 1024), isFalse);
      expect(cap.sendsFileNatively('lon.pdf', 5242881), isFalse);
    });

    // OutboundCapabilities.php @ fa8acbc: Zalo OA có `image_constraints`
    // (JPG/PNG ≤ 1MB, fallback `failed`) và `fallback: link` cho tệp.
    test(
      'image_constraints + fallback: GIF / ảnh >1MB sẽ LỖI, không thành link',
      () {
        final cap = OutboundCapabilities.fromJson({
          'can_send': true,
          'text': 'native',
          'image': 'native',
          'file': 'docs_only',
          'audio': 'link',
          'video': 'link',
          'file_constraints': {
            'native_extensions': ['pdf', 'doc', 'docx', 'csv'],
            'native_max_bytes': 5242880,
            'fallback': 'link',
          },
          'image_constraints': {
            'native_extensions': ['jpg', 'jpeg', 'png'],
            'native_max_bytes': 1048576,
            'fallback': 'failed',
          },
        })!;
        expect(cap.fileConstraints!.fallback, 'link');
        expect(cap.imageConstraints!.fallback, 'failed');
        expect(cap.imageConstraints!.nativeMaxBytes, 1048576);
        // Ảnh xét theo ĐUÔI: JPG/PNG/WebP lớn được server nén lại ≤ 1MB lúc
        // tải lên (InboxImageCompressor), nên cỡ không quyết định.
        final ic = cap.imageConstraints!;
        expect(ic.allowsExtension('a.JPG'), isTrue);
        expect(ic.allowsExtension('a.png'), isTrue);
        expect(ic.allowsExtension('a.gif'), isFalse);
        expect(ic.allowsExtension('a.webp'), isFalse);
      },
    );

    test('image_constraints null (Facebook) → không báo lỗi ảnh trước', () {
      final cap = OutboundCapabilities.fromJson({
        'can_send': true,
        'text': 'native',
        'image': 'native',
        'file': 'native',
        'audio': 'native',
        'video': 'native',
        'file_constraints': null,
        'image_constraints': null,
      })!;
      expect(cap.imageConstraints, isNull);
      expect(cap.fileConstraints, isNull);
    });

    test('bỏ chặn: server XOÁ khoá blocked_at → isBlocked false', () {
      final c = Conversation.fromJson({'id': 'c1', 'channel': 'zalo'});
      expect(c.blockedAt, isNull);
      expect(c.isBlocked, isFalse);
    });

    test(
      'docs_only thiếu file_constraints (API cũ) → mặc định PDF/DOC/DOCX/CSV ≤5MB',
      () {
        final cap = OutboundCapabilities.fromJson({
          'can_send': true,
          'text': 'native',
          'image': 'native',
          'file': 'docs_only',
          'audio': 'link',
          'video': 'link',
        })!;
        expect(cap.fileConstraints, isNull);
        expect(cap.sendsFileNatively('a.docx', 10), isTrue);
        expect(cap.sendsFileNatively('a.xlsx', 10), isFalse);
        expect(cap.sendsFileNatively('a.pdf', 6 * 1024 * 1024), isFalse);
      },
    );

    test('native gửi mọi tệp thành tệp thật; link thì không tệp nào', () {
      OutboundCapabilities of(String file) => OutboundCapabilities.fromJson({
        'can_send': true,
        'text': 'native',
        'image': 'native',
        'file': file,
        'audio': 'native',
        'video': 'native',
      })!;
      expect(of('native').sendsFileNatively('a.xlsx', 20 << 20), isTrue);
      expect(of('link').sendsFileNatively('a.pdf', 10), isFalse);
    });

    test('kênh không gửi được (can_send:false, mọi loại none)', () {
      final cap = OutboundCapabilities.fromJson({
        'can_send': false,
        'text': 'none',
        'image': 'none',
        'file': 'none',
        'audio': 'none',
        'video': 'none',
      })!;
      expect(cap.canSendText, isFalse);
      expect(cap.canSendImages, isFalse);
      expect(cap.canSendFiles, isFalse);
      expect(cap.canSendVoice, isFalse);
    });

    test('can_send:false thắng giá trị native lẻ', () {
      final cap = OutboundCapabilities.fromJson({
        'can_send': false,
        'text': 'native',
        'image': 'native',
        'file': 'native',
        'audio': 'native',
        'video': 'native',
      })!;
      expect(cap.canSendText, isFalse);
      expect(cap.canSendFiles, isFalse);
    });

    test('giá trị lạ → none', () {
      expect(OutboundMode.parse('docs_only'), OutboundMode.docsOnly);
      expect(OutboundMode.parse('native'), OutboundMode.native);
      expect(OutboundMode.parse('link'), OutboundMode.link);
      expect(OutboundMode.parse('none'), OutboundMode.none);
      expect(OutboundMode.parse('weird'), OutboundMode.none);
      expect(OutboundMode.parse(null), OutboundMode.none);
    });

    test('API cũ thiếu khoá → null (không đoán), cờ mặc định false', () {
      final c = Conversation.fromJson({'id': 'c', 'channel': 'facebook'});
      expect(c.outboundCapabilities, isNull);
      expect(c.isPinned, isFalse);
      expect(c.isMuted, isFalse);
      expect(c.isBlocked, isFalse);
      expect(c.blockedAt, isNull);
      expect(
        Conversation.fromJson({'id': 'c', 'blocked_at': null}).isBlocked,
        isFalse,
      );
    });

    test('mảng thô pinned_by/muted_by KHÔNG được dùng thay cờ', () {
      final c = Conversation.fromJson({
        'id': 'c',
        'channel': 'zalo',
        'pinned_by': ['me'],
        'muted_by': ['me'],
      });
      expect(c.isPinned, isFalse);
      expect(c.isMuted, isFalse);
    });
  });

  group('tin: team_reactions + error_code', () {
    test('team_reactions tách khỏi reaction của khách', () {
      final m = Message.fromJson({
        'id': 'm1',
        'direction': 'in',
        'text': 'hi',
        'reaction': '😮',
        'team_reactions': [
          {
            'user_id': 'u1',
            'user_name': 'Lan',
            'emoji': '❤️',
            'at': '2026-10-10T03:00:00.000Z',
          },
        ],
      });
      expect(m.reaction, '😮');
      expect(m.teamReactions.single.userId, 'u1');
      expect(m.teamReactions.single.userName, 'Lan');
      expect(m.teamReactions.single.emoji, '❤️');
      expect(m.teamReactions.single.at, DateTime.utc(2026, 10, 10, 3));
    });

    test('thiếu team_reactions → rỗng', () {
      final m = Message.fromJson({'id': 'm', 'direction': 'in'});
      expect(m.teamReactions, isEmpty);
      expect(m.errorCode, isNull);
      expect(m.isChannelUnsupported, isFalse);
    });

    test('failed + error_code channel_send_unsupported', () {
      final m = Message.fromJson({
        'id': 'm2',
        'direction': 'out',
        'status': 'failed',
        'error': 'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư — …',
        'error_code': 'channel_send_unsupported',
        'team_reactions': [
          {'user_id': 'u1', 'emoji': '👍'},
        ],
      });
      expect(m.errorCode, 'channel_send_unsupported');
      expect(m.isChannelUnsupported, isTrue);
      final again = m.requeued();
      expect(again.errorCode, isNull);
      expect(again.teamReactions, isEmpty);
    });

    test('copyWith giữ team_reactions + error_code', () {
      final m = Message.fromJson({
        'id': 'm3',
        'direction': 'out',
        'status': 'failed',
        'error_code': 'channel_send_unsupported',
        'team_reactions': [
          {'user_id': 'u1', 'emoji': '👍'},
        ],
      });
      final same = m.copyWith(pinned: true);
      expect(same.errorCode, 'channel_send_unsupported');
      expect(same.teamReactions.single.emoji, '👍');
      final changed = m.copyWith(
        teamReactions: const [TeamReaction(userId: 'u2', emoji: '❤️')],
      );
      expect(changed.teamReactions.single.userId, 'u2');
    });

    // Biên nhận realtime đổi `failed` → `sent`: mã lỗi cũ không được ở lại,
    // nếu không bong bóng đã gửi được vẫn bị coi là "kênh không gửi được".
    test('copyWith: status rời failed → errorCode về null', () {
      final m = Message.fromJson({
        'id': 'm4',
        'direction': 'out',
        'status': 'failed',
        'error_code': 'channel_not_configured',
      });
      expect(m.copyWith(status: DeliveryStatus.sent).errorCode, isNull);
      expect(m.copyWith(status: DeliveryStatus.read).errorCode, isNull);
      // Vẫn failed (hoặc không đổi status) thì giữ mã.
      expect(
        m.copyWith(status: DeliveryStatus.failed).errorCode,
        'channel_not_configured',
      );
      expect(m.copyWith(pinned: true).errorCode, 'channel_not_configured');
      // Truyền rõ mã mới cùng status failed thì lấy mã mới.
      expect(
        m
            .copyWith(
              status: DeliveryStatus.failed,
              errorCode: 'channel_send_unsupported',
            )
            .errorCode,
        'channel_send_unsupported',
      );
    });
  });

  test('POST …/unread → data.unread_count', () async {
    final (a, http) = api({'unread_count': 1});
    expect(await a.markUnread('c1'), 1);
    final r = http.requests.single;
    expect(r.method, 'POST');
    expect(r.uri.path, '/api/v1/inbox/conversations/c1/unread');
  });

  test('ghim/bỏ ghim: POST|DELETE …/pin → data.is_pinned', () async {
    final (on, h1) = api({'conversation_id': 'c1', 'is_pinned': true});
    expect(await on.setPinned('c1', true), isTrue);
    expect(h1.requests.single.method, 'POST');
    expect(h1.requests.single.uri.path, '/api/v1/inbox/conversations/c1/pin');
    final (off, h2) = api({'conversation_id': 'c1', 'is_pinned': false});
    expect(await off.setPinned('c1', false), isFalse);
    expect(h2.requests.single.method, 'DELETE');
    expect(h2.requests.single.uri.path, '/api/v1/inbox/conversations/c1/pin');
  });

  test('422 pin_limit_reached → ValidationException.reason', () async {
    final (a, _) = api(
      const {},
      status: 422,
      raw: jsonEncode({
        'success': false,
        'code': 'pin_limit_reached',
        'message':
            'Bạn đã ghim tối đa 50 hội thoại — bỏ ghim bớt rồi ghim lại.',
        'errors': {
          'conversation_id': ['…'],
        },
        'data': {'conversation_id': 'c1', 'is_pinned': false},
      }),
    );
    await expectLater(
      a.setPinned('c1', true),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.reason, 'reason', 'pin_limit_reached')
            .having((e) => e.message, 'message', contains('tối đa 50')),
      ),
    );
  });

  test('tắt/bật TB: POST|DELETE …/mute → data.is_muted', () async {
    final (on, h1) = api({'conversation_id': 'c1', 'is_muted': true});
    expect(await on.setMuted('c1', true), isTrue);
    expect(h1.requests.single.method, 'POST');
    expect(h1.requests.single.uri.path, '/api/v1/inbox/conversations/c1/mute');
    final (off, h2) = api({'conversation_id': 'c1', 'is_muted': false});
    expect(await off.setMuted('c1', false), isFalse);
    expect(h2.requests.single.method, 'DELETE');
    expect(h2.requests.single.uri.path, '/api/v1/inbox/conversations/c1/mute');
  });

  test('chặn: POST …/block → hội thoại đầy đủ', () async {
    final (a, h) = api({
      'id': 'c1',
      'channel': 'zalo',
      'customer_name': 'Lan',
      'source_name': 'OA TNP',
      'blocked_at': '2026-10-10T03:00:00.000Z',
      'blocked_by': 'u9',
      'is_pinned': false,
      'is_muted': false,
    });
    final c = await a.setBlocked('c1', true);
    expect(c.id, 'c1');
    expect(c.isBlocked, isTrue);
    expect(c.sourceName, 'OA TNP');
    expect(h.requests.single.method, 'POST');
    expect(h.requests.single.uri.path, '/api/v1/inbox/conversations/c1/block');
  });

  test('bỏ chặn: DELETE …/block, blocked_at null → isBlocked false', () async {
    final (a, h) = api({
      'id': 'c1',
      'channel': 'zalo',
      'blocked_at': null,
      'blocked_by': null,
    });
    final c = await a.setBlocked('c1', false);
    expect(c.isBlocked, isFalse);
    expect(h.requests.single.method, 'DELETE');
    expect(h.requests.single.uri.path, '/api/v1/inbox/conversations/c1/block');
  });

  test('cảm xúc nội bộ: POST …/team-reactions {emoji}', () async {
    final (a, h) = api({
      'message_id': 'm1',
      'team_reactions': [
        {
          'user_id': 'u1',
          'user_name': 'Lan',
          'emoji': '❤️',
          'at': '2026-10-10T03:00:00.000Z',
        },
      ],
    });
    final list = await a.toggleTeamReaction('c1', 'm1', '❤️');
    expect(list.single.emoji, '❤️');
    expect(list.single.userName, 'Lan');
    final r = h.requests.single;
    expect(r.method, 'POST');
    expect(
      r.uri.path,
      '/api/v1/inbox/conversations/c1/messages/m1/team-reactions',
    );
    expect(r.data, {'emoji': '❤️'});
  });

  test('list pinned → query pinned=1 / pinned=0, null → không gửi', () async {
    final page = envelope(const []);
    for (final (value, expected) in [(true, '1'), (false, '0'), (null, null)]) {
      final adapter = FakeAdapter(200, page);
      final a = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));
      await a.list(query: const {'status': 'open'}, pinned: value);
      final q = adapter.requests.single.uri.queryParameters;
      expect(q['pinned'], expected, reason: 'pinned: $value');
      expect(q.containsKey('pinned'), value != null);
      expect(q['status'], 'open');
    }
  });

  test('trang sau (before) vẫn mang pinned, không kèm cursor=1', () async {
    final adapter = FakeAdapter(200, envelope(const []));
    final a = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));
    await a.list(
      query: const {'status': 'open'},
      before: '2026-10-10T03:00:00.000Z|c9',
      pinned: false,
    );
    final q = adapter.requests.single.uri.queryParameters;
    expect(q['pinned'], '0');
    expect(q['before'], '2026-10-10T03:00:00.000Z|c9');
    expect(q.containsKey('cursor'), isFalse);
    expect(q['status'], 'open');
  });

  test('gửi tin: attachments.type chỉ image|video|audio|file', () async {
    final (a, h) = api({'id': 'm9', 'direction': 'out', 'status': 'queued'});
    await a.send(
      'c1',
      attachments: const [
        MessageAttachment(url: 'u', type: 'audio', name: 'a.wav'),
      ],
    );
    final body = h.requests.single.data as Map;
    expect(body['attachments'], [
      {'url': 'u', 'type': 'audio', 'name': 'a.wav'},
    ]);
  });

  test(
    'gửi 1 ảnh + 1 tệp: type lấy từ phản hồi upload, không từ đuôi',
    () async {
      // `InboxController::uploadMedia`: `{url, type, name}`, type theo MIME DÒ
      // được (image|video|audio|file). Một `.xlsx` bị dò thành gì thì gửi đúng
      // cái đó — Facebook dùng nó làm loại attachment.
      final image = MessageAttachment.fromUpload(const {
        'url': 'https://x/api/v1/inbox/media/t1/a.jpg?signature=s',
        'type': 'image',
        'name': 'a.png',
      });
      final doc = MessageAttachment.fromUpload(const {
        'url': 'https://x/api/v1/inbox/media/t1/b.xlsx?signature=s',
        'type': 'file',
        'name': 'bang-gia.xlsx',
      });
      final (a, h) = api({'id': 'm9', 'direction': 'out', 'status': 'queued'});
      await a.send('c1', text: 'Báo giá', attachments: [image, doc]);
      final body = h.requests.single.data as Map;
      expect(body['attachments'], [
        {
          'url': 'https://x/api/v1/inbox/media/t1/a.jpg?signature=s',
          'type': 'image',
          'name': 'a.png',
        },
        {
          'url': 'https://x/api/v1/inbox/media/t1/b.xlsx?signature=s',
          'type': 'file',
          'name': 'bang-gia.xlsx',
        },
      ]);
    },
  );

  test('gửi ghi âm: một tệp audio từ upload, không có khoá text', () async {
    // Bản ghi WAV dò ra `audio/x-wav` → upload trả `type: audio`.
    final voice = MessageAttachment.fromUpload(const {
      'url': 'https://x/api/v1/inbox/media/t1/v.wav?signature=s',
      'type': 'audio',
      'name': 'ghi-am-20261010-090507.wav',
    });
    final (a, h) = api({'id': 'm9', 'direction': 'out', 'status': 'queued'});
    // ThreadController.sendAfterUpload gửi chữ rỗng cho tin ghi âm.
    await a.send('c1', text: '', attachments: [voice]);
    final r = h.requests.single;
    expect(r.method, 'POST');
    expect(r.uri.path, '/api/v1/inbox/conversations/c1/messages');
    final body = r.data as Map;
    expect(body.containsKey('text'), isFalse);
    expect(body['attachments'], [
      {
        'url': 'https://x/api/v1/inbox/media/t1/v.wav?signature=s',
        'type': 'audio',
        'name': 'ghi-am-20261010-090507.wav',
      },
    ]);
  });

  group('gửi lại: POST …/messages/{mid}/resend (API 0cd1713)', () {
    test('200 → tin được mở lại, body rỗng', () async {
      final (a, h) = api({
        'id': 'm2',
        'direction': 'out',
        'status': 'queued',
        'text': 'Dạ em gửi ạ',
      });
      final m = await a.resend('c1', 'm2');
      expect(m.id, 'm2');
      expect(m.status, DeliveryStatus.queued);
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '/api/v1/inbox/conversations/c1/messages/m2/resend');
      expect(r.data, isNull);
    });

    test('422 message_too_old_to_resend → reason', () async {
      final (a, _) = api(
        const {},
        status: 422,
        raw: jsonEncode({
          'success': false,
          'code': 'message_too_old_to_resend',
          'message': 'Tin này đã quá lâu để gửi lại — hãy gửi một tin mới.',
        }),
      );
      await expectLater(
        a.resend('c1', 'm2'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.reason,
            'reason',
            'message_too_old_to_resend',
          ),
        ),
      );
    });

    test('409 message_not_failed mang data → MessageNotFailedException với '
        'tin hiện tại', () async {
      final (a, _) = api(
        const {},
        status: 409,
        raw: jsonEncode({
          'success': false,
          'code': 'message_not_failed',
          'message':
              'Tin này không ở trạng thái gửi lỗi nên không gửi lại được.',
          // `InboxController::resendMessage`: tin hiện tại, client thay bong
          // bóng bằng nó.
          'data': {
            'id': 'm2',
            'direction': 'out',
            'from': 'agent',
            'status': 'sent',
            'text': 'Dạ em gửi ạ',
          },
        }),
      );
      await expectLater(
        a.resend('c1', 'm2'),
        throwsA(
          isA<MessageNotFailedException>()
              .having((e) => e.current?.id, 'current.id', 'm2')
              .having(
                (e) => e.current?.status,
                'current.status',
                DeliveryStatus.sent,
              )
              .having(
                (e) => e.message,
                'message',
                'Tin này không ở trạng thái gửi lỗi nên không gửi lại được.',
              ),
        ),
      );
    });

    test(
      '409 không có data → MessageNotFailedException, current null',
      () async {
        final (a, _) = api(
          const {},
          status: 409,
          raw: jsonEncode({
            'success': false,
            'code': 'message_not_failed',
            'message': 'Tin này không ở trạng thái gửi lỗi.',
            'data': null,
          }),
        );
        await expectLater(
          a.resend('c1', 'm2'),
          throwsA(
            isA<MessageNotFailedException>().having(
              (e) => e.current,
              'current',
              isNull,
            ),
          ),
        );
      },
    );

    test('409 khác mã (không phải message_not_failed) → vẫn '
        'RequestRejectedException', () async {
      final (a, _) = api(
        const {},
        status: 409,
        raw: jsonEncode({'success': false, 'message': 'Xung đột.'}),
      );
      await expectLater(
        a.resend('c1', 'm2'),
        throwsA(
          isA<RequestRejectedException>().having((e) => e.code, 'code', '409'),
        ),
      );
    });
  });

  test('gửi tin vào kênh không gửi được → 422 mang mã nghiệp vụ', () async {
    final (a, _) = api(
      const {},
      status: 422,
      raw: jsonEncode({
        'success': false,
        'code': 'channel_send_unsupported',
        'message': 'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.',
      }),
    );
    await expectLater(
      a.send('c1', text: 'hi'),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.reason,
          'reason',
          'channel_send_unsupported',
        ),
      ),
    );
  });

  // `AbstractChannelConnector::unconfiguredAck` (production): kết nối thiếu
  // token → tin `failed` mang `error_code: channel_not_configured` — KHÔNG phải
  // lỗi HTTP. Khác `channel_send_unsupported`: kết nối lại rồi gửi lại được.
  test('tin failed channel_not_configured: đọc mã, vẫn gửi lại được', () {
    final m = Message.fromJson({
      'id': 'm4',
      'direction': 'out',
      'status': 'failed',
      'error':
          'Kết nối kênh chưa có mã truy cập nên tin chưa đến khách — admin '
          'cần kết nối lại tài khoản trong phần Kênh.',
      'error_code': 'channel_not_configured',
    });
    expect(m.status, DeliveryStatus.failed);
    expect(m.errorCode, 'channel_not_configured');
    expect(m.isChannelUnsupported, isFalse);
    expect(m.error, contains('kết nối lại'));
  });

  group('quyền (routes.php feat/hop-thu-mobile)', () {
    InboxAccess of(Set<String> slugs) => InboxAccess.of(AccessPolicy(slugs));

    test('đủ quyền: cảm xúc + chặn', () {
      final a = of({'inbox.read', 'inbox.write'});
      expect(a.canReact, isTrue);
      expect(a.canBlock, isTrue);
      expect(of({'inbox.read.all', 'inbox.write'}).canBlock, isTrue);
    });

    test('sale .own có ghi: cảm xúc có, chặn KHÔNG (route 403)', () {
      final a = of({'inbox.read.own', 'inbox.write'});
      expect(a.canReact, isTrue);
      expect(a.canBlock, isFalse);
    });

    test('chỉ đọc: không cảm xúc, không chặn', () {
      final a = of({'inbox.read'});
      expect(a.canReact, isFalse);
      expect(a.canBlock, isFalse);
    });
  });

  test(
    'trần phía app: 10 tệp/tin (UX), 25MB/tệp (= uploadMedia max:25600)',
    () {
      expect(InboxApi.maxAttachmentsPerMessage, 10);
      expect(InboxApi.maxUploadBytes, 25 * 1024 * 1024);
    },
  );
}
