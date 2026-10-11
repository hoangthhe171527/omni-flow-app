import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/team_reactions.dart';

/// Cảm xúc NỘI BỘ của đội (`team_reactions`) — viên dưới bong bóng, tách hẳn
/// khỏi vòng tròn cảm xúc của KHÁCH ở góc bong bóng.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const lan = TeamReaction(userId: 'u2', userName: 'Lan', emoji: '❤️');
  const minh = TeamReaction(userId: 'u3', userName: 'Minh', emoji: '❤️');
  const me = TeamReaction(userId: 'u1', userName: 'Kiệt', emoji: '👍');

  Message message({
    String? reaction,
    List<TeamReaction> team = const [lan, minh, me],
  }) => Message(
    id: 'm1',
    author: MessageAuthor.customer,
    text: 'Còn đàn không shop',
    sentAt: DateTime.utc(2026, 1, 1, 8),
    reaction: reaction,
    teamReactions: team,
  );

  Widget host(Widget child, {bool dark = false}) => MaterialApp(
    theme: dark
        ? OmniTheme.dark(TargetPlatform.android)
        : OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: Center(child: child)),
  );

  group('viên cảm xúc nội bộ', () {
    testWidgets('khách 😮 + đội [❤️ Lan, ❤️ Minh, 👍 tôi] → hiện cả hai loại', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MessageBubble(
            message: message(reaction: '😮'),
            myUserId: 'u1',
          ),
        ),
      );
      expect(find.text('😮'), findsOneWidget);
      expect(find.text('❤️ 2'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Cảm xúc của khách: 😮')),
        findsOneWidget,
      );
    });

    testWidgets('Semantics "Cảm xúc nội bộ: ❤️ Lan, Minh"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          TeamReactionChips(reactions: const [lan, minh, me], myUserId: 'u1'),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Cảm xúc nội bộ: ❤️ Lan, Minh')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('viên của tôi viền màu chính, của người khác viền nhạt', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(TeamReactionChips(reactions: const [lan, me], myUserId: 'u1')),
      );
      final context = tester.element(find.byType(TeamReactionChips));
      final scheme = Theme.of(context).colorScheme;
      Color borderOf(String emoji) =>
          ((tester
                              .widget<Container>(
                                find.byKey(ValueKey('team-reaction-$emoji')),
                              )
                              .decoration!
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      expect(borderOf('👍'), scheme.primary);
      expect(borderOf('❤️'), scheme.outlineVariant);
    });

    testWidgets('vùng chạm cao ≥44', (tester) async {
      await tester.pumpWidget(
        host(TeamReactionChips(reactions: const [lan], myUserId: 'u1')),
      );
      final tap = find.byKey(const ValueKey('team-reactions-tap'));
      expect(tester.getSize(tap).height, greaterThanOrEqualTo(44));
    });

    testWidgets('chạm viên → sheet liệt kê người thả', (tester) async {
      await tester.pumpWidget(
        host(
          TeamReactionChips(
            reactions: const [
              lan,
              minh,
              TeamReaction(userId: 'u4', emoji: '😂'),
            ],
            myUserId: 'u1',
          ),
        ),
      );
      await tester.tap(find.text('❤️ 2'));
      await tester.pumpAndSettle();
      expect(find.text('Cảm xúc nội bộ'), findsOneWidget);
      expect(find.text('Lan'), findsOneWidget);
      expect(find.text('Minh'), findsOneWidget);
      expect(find.text('Thành viên'), findsOneWidget, reason: 'tên null');
    });

    testWidgets('tên lấy theo user_id trong danh bạ, hơn tên chụp lại', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TeamReactionChips(
            reactions: const [lan],
            myUserId: 'u1',
            memberNames: const {'u2': 'Lan Nguyễn'},
          ),
        ),
      );
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();
      expect(find.text('Lan Nguyễn'), findsOneWidget);
      expect(find.text('Lan'), findsNothing);
    });

    testWidgets('giao diện tối: nền viên không phải trắng cứng', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TeamReactionChips(reactions: const [lan], myUserId: 'u1'),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      final box =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('team-reaction-❤️')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, isNot(Colors.white));
      expect(box.color!.computeLuminance(), lessThan(0.3));
    });

    testWidgets('không có cảm xúc nội bộ → không dựng gì', (tester) async {
      await tester.pumpWidget(
        host(
          MessageBubble(
            message: message(team: const []),
            myUserId: 'u1',
          ),
        ),
      );
      // Viên luôn được dựng (giữ state cho hiệu ứng nảy) nhưng rỗng thì không
      // vẽ gì, không có vùng chạm.
      expect(find.byKey(const ValueKey('team-reactions-tap')), findsNothing);
    });
  });

  group('ThreadController.toggleTeamReaction', () {
    late _FakeInboxApi api;
    late ProviderContainer container;

    setUp(() {
      api = _FakeInboxApi();
      container = ProviderContainer(
        overrides: [inboxApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    List<TeamReaction> reactionsOf(String id) => container
        .read(threadProvider('c1'))
        .requireValue
        .messages
        .firstWhere((m) => m.id == id)
        .teamReactions;

    test('lạc quan: thêm ngay, rồi thay bằng danh sách server', () async {
      api.history = [
        message(team: const [lan]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final gate = Completer<List<TeamReaction>>();
      api.answer = gate;

      final done = container
          .read(threadProvider('c1').notifier)
          .toggleTeamReaction('m1', '👍', myUserId: 'u1', myName: 'Kiệt');
      expect(reactionsOf('m1').map((r) => '${r.userId}:${r.emoji}'), [
        'u2:❤️',
        'u1:👍',
      ]);

      gate.complete(const [
        lan,
        TeamReaction(userId: 'u1', userName: 'Kiệt (server)', emoji: '👍'),
      ]);
      await done;
      expect(reactionsOf('m1').last.userName, 'Kiệt (server)');
      expect(api.calls, [('c1', 'm1', '👍')]);
    });

    test('cùng emoji của tôi → bỏ; khác → thay', () async {
      api.history = [
        message(team: const [lan, me]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final notifier = container.read(threadProvider('c1').notifier);

      api.answer = Completer<List<TeamReaction>>();
      unawaited(notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1'));
      expect(reactionsOf('m1').map((r) => r.userId), ['u2']);
      api.answer!.complete(const [lan]);
      await Future<void>.delayed(Duration.zero);

      api.answer = Completer<List<TeamReaction>>();
      unawaited(notifier.toggleTeamReaction('m1', '❤️', myUserId: 'u1'));
      expect(reactionsOf('m1').map((r) => '${r.userId}:${r.emoji}'), [
        'u2:❤️',
        'u1:❤️',
      ]);
      api.answer!.complete(const [lan]);
      await Future<void>.delayed(Duration.zero);
    });

    test('lỗi → trả danh sách cũ rồi ném lại', () async {
      api.history = [
        message(team: const [lan]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      api.fail = true;

      await expectLater(
        container
            .read(threadProvider('c1').notifier)
            .toggleTeamReaction('m1', '👍', myUserId: 'u1'),
        throwsA(isA<ServerException>()),
      );
      expect(reactionsOf('m1').map((r) => r.userId), ['u2']);
    });

    test(
      'realtime về GIỮA lạc quan và phản hồi: áp ngay, phản hồi thay sau',
      () async {
        api.history = [
          message(team: const [lan]),
        ];
        container.listen(threadProvider('c1'), (_, _) {});
        await container.read(threadProvider('c1').future);
        final notifier = container.read(threadProvider('c1').notifier);
        final gate = Completer<List<TeamReaction>>();
        api.answer = gate;

        final done = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
        // Sự kiện `message.team_reaction` của chính lượt này + Minh vừa thả.
        notifier.applyTeamReactions('m1', const [lan, minh, me]);
        expect(reactionsOf('m1').map((r) => r.userId), ['u2', 'u3', 'u1']);

        gate.complete(const [lan, minh, me]);
        await done;
        expect(reactionsOf('m1').map((r) => '${r.userId}:${r.emoji}'), [
          'u2:❤️',
          'u3:❤️',
          'u1:👍',
        ]);
      },
    );

    test('lỗi sau khi realtime đã về → chỉ trả lại mục CỦA TÔI, giữ của người '
        'khác', () async {
      api.history = [
        message(team: const [lan]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final notifier = container.read(threadProvider('c1').notifier);
      final gate = Completer<List<TeamReaction>>();
      api.answer = gate;

      final done = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
      // Minh thả trong lúc chờ (realtime).
      notifier.applyTeamReactions('m1', const [
        lan,
        minh,
        TeamReaction(userId: 'u1', emoji: '👍'),
      ]);
      gate.completeError(const ServerException('Lỗi máy chủ.'));
      await expectLater(done, throwsA(isA<ServerException>()));
      expect(reactionsOf('m1').map((r) => '${r.userId}:${r.emoji}'), [
        'u2:❤️',
        'u3:❤️',
      ]);
    });

    test('lỗi khi trước đó tôi đã có emoji → trả lại đúng emoji cũ', () async {
      api.history = [
        message(team: const [lan, me]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      api.fail = true;
      await expectLater(
        container
            .read(threadProvider('c1').notifier)
            .toggleTeamReaction('m1', '❤️', myUserId: 'u1'),
        throwsA(isA<ServerException>()),
      );
      expect(reactionsOf('m1').map((r) => '${r.userId}:${r.emoji}'), [
        'u2:❤️',
        'u1:👍',
      ]);
    });

    test(
      'hai lượt nhanh: phản hồi CŨ về sau không đè trạng thái mới',
      () async {
        api.history = [
          message(team: const [lan]),
        ];
        container.listen(threadProvider('c1'), (_, _) {});
        await container.read(threadProvider('c1').future);
        final notifier = container.read(threadProvider('c1').notifier);

        final first = Completer<List<TeamReaction>>();
        api.answer = first;
        final one = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
        final second = Completer<List<TeamReaction>>();
        api.answer = second;
        final two = notifier.toggleTeamReaction('m1', '❤️', myUserId: 'u1');
        expect(reactionsOf('m1').last.emoji, '❤️');

        // Lượt 2 về trước, lượt 1 (cũ) về sau.
        second.complete(const [lan, TeamReaction(userId: 'u1', emoji: '❤️')]);
        await two;
        first.complete(const [lan, TeamReaction(userId: 'u1', emoji: '👍')]);
        await one;
        expect(reactionsOf('m1').last.emoji, '❤️');
      },
    );

    test('lượt cũ lỗi sau khi lượt mới đã xong → không hoàn tác gì', () async {
      api.history = [
        message(team: const [lan]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final notifier = container.read(threadProvider('c1').notifier);

      final first = Completer<List<TeamReaction>>();
      api.answer = first;
      final one = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
      final second = Completer<List<TeamReaction>>();
      api.answer = second;
      final two = notifier.toggleTeamReaction('m1', '❤️', myUserId: 'u1');
      second.complete(const [lan, TeamReaction(userId: 'u1', emoji: '❤️')]);
      await two;
      first.completeError(const ServerException('x'));
      await expectLater(one, throwsA(isA<ServerException>()));
      expect(reactionsOf('m1').last.emoji, '❤️');
    });

    for (final secondFailsFirst in [true, false]) {
      test('hai lượt cùng lỗi (lượt ${secondFailsFirst ? 'mới' : 'cũ'} lỗi '
          'trước) → về đúng trạng thái TRƯỚC lượt đầu', () async {
        api.history = [
          message(team: const [lan]),
        ];
        container.listen(threadProvider('c1'), (_, _) {});
        await container.read(threadProvider('c1').future);
        final notifier = container.read(threadProvider('c1').notifier);

        final first = Completer<List<TeamReaction>>();
        api.answer = first;
        final one = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
        final second = Completer<List<TeamReaction>>();
        api.answer = second;
        final two = notifier.toggleTeamReaction('m1', '❤️', myUserId: 'u1');

        Future<void> fail(
          Completer<List<TeamReaction>> c,
          Future<void> f,
        ) async {
          c.completeError(const ServerException('x'));
          await expectLater(f, throwsA(isA<ServerException>()));
        }

        if (secondFailsFirst) {
          await fail(second, two);
          await fail(first, one);
        } else {
          await fail(first, one);
          await fail(second, two);
        }
        expect(reactionsOf('m1').map((r) => r.userId), [lan.userId]);
      });
    }

    test('lượt mới lỗi trước, lượt cũ thành công sau → theo kết quả server '
        'của lượt cũ', () async {
      api.history = [
        message(team: const [lan]),
      ];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final notifier = container.read(threadProvider('c1').notifier);

      final first = Completer<List<TeamReaction>>();
      api.answer = first;
      final one = notifier.toggleTeamReaction('m1', '👍', myUserId: 'u1');
      final second = Completer<List<TeamReaction>>();
      api.answer = second;
      final two = notifier.toggleTeamReaction('m1', '❤️', myUserId: 'u1');

      second.completeError(const ServerException('x'));
      await expectLater(two, throwsA(isA<ServerException>()));
      first.complete(const [lan, TeamReaction(userId: 'u1', emoji: '👍')]);
      await one;
      expect(reactionsOf('m1').last.emoji, '👍');
    });

    test('tin không có trên màn → bỏ qua, không gọi API', () async {
      api.history = [message(team: const [])];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);

      await container
          .read(threadProvider('c1').notifier)
          .toggleTeamReaction('m-khac', '👍', myUserId: 'u1');
      expect(api.calls, isEmpty);
    });

    test('applyTeamReactions: vá tin đang có, tin chưa tải → false', () async {
      api.history = [message(team: const [])];
      container.listen(threadProvider('c1'), (_, _) {});
      await container.read(threadProvider('c1').future);
      final notifier = container.read(threadProvider('c1').notifier);

      expect(notifier.applyTeamReactions('m1', const [minh]), isTrue);
      expect(reactionsOf('m1').single.userId, 'u3');
      expect(notifier.applyTeamReactions('m-la', const [minh]), isFalse);
    });
  });
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Message> history = const [];
  Completer<List<TeamReaction>>? answer;
  bool fail = false;
  final calls = <(String, String, String)>[];

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async => MessagePage(
    messages: history.reversed.toList(),
    cursor: const CursorPage.empty(),
  );

  @override
  Future<List<TeamReaction>> toggleTeamReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    calls.add((conversationId, messageId, emoji));
    if (fail) throw const ServerException('Lỗi máy chủ.');
    return answer!.future;
  }
}
