# Channels Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho phép nối kênh (Facebook Page, Zalo OA, TikTok qua OAuth; Zalo/Facebook cá nhân qua QR) trực tiếp từ app mobile, không cần mở web.

**Architecture:** Một module Flutter mới `lib/modules/channels/` theo khuôn `OmniModule` sẵn có — domain thuần Dart, data gọi `ApiClient`, application là Riverpod provider, presentation là widget. Backend đã đủ endpoint nên không sửa dòng nào bên `omnicrm-pro-api`. Ghép nối QR nằm ở một trang riêng vì đó là tiến trình sống tới 30 phút có state.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5, flutter_riverpod 2.6, go_router 14.8, dio 5.4, url_launcher 6.3 (đã có), gal (thêm mới).

**Spec:** `docs/superpowers/specs/2026-08-04-channels-mobile-design.md`

## Global Constraints

- Không sửa bất kỳ file nào trong `d:\TrungNguyenCRM\omnicrm-pro-api` hay `omnicrm-pro-source`.
- Gói mới duy nhất được thêm: `gal`. Không thêm gói HTTP, state management, QR hay path_provider nào khác.
- Mọi đường dẫn truyền vào `ApiClient` là **tương đối với `/api/v1`** — viết `/channels`, không viết `/api/v1/channels`.
- Toàn bộ chữ hiển thị bằng tiếng Việt.
- Đọc JSON qua extension `JsonMap` trong `lib/core/utils/json.dart` (`str`, `strOr`, `intOr`), không cast trực tiếp — API là Mongo schema-less.
- Tái dùng `Channel`, `ChannelKind`, `ChannelMeta` từ `lib/core/domain/channel.dart`. Không định nghĩa lại tên, màu hay icon kênh.
- Tái dùng design token và component: `OmniCard`, `OmniAsyncView`, `OmniEmptyState`, `OmniStatusChip`, `OmniTone`, `OmniSpacing`, `OmniType`, `OmniColors`.
- Tham số callback không dùng viết `_` (lint hiện tại chấp nhận `(_, _)`), theo đúng code sẵn có.
- Chạy test bằng `flutter test`, phân tích bằng `flutter analyze`. Cả hai phải sạch trước mỗi commit.

## File Structure

| File | Trách nhiệm |
|---|---|
| `lib/modules/channels/domain/channel_permissions.dart` | 3 slug quyền + nhóm `anyRead`/`all` |
| `lib/modules/channels/domain/channel_connection.dart` | `ChannelStatus` + model `ChannelConnection` và parsing |
| `lib/modules/channels/domain/connectable_channel.dart` | `ConnectMethod` + kênh nào nối bằng cách nào |
| `lib/modules/channels/domain/pairing.dart` | `PairingStart`, `PairingStatus`, `PairingView`, hàm thuần `resolvePairing`, `shouldShowAgentHint` |
| `lib/modules/channels/data/channels_api.dart` | Chỗ duy nhất viết đường dẫn `/channels/...` |
| `lib/modules/channels/application/channels_providers.dart` | `channelsProvider` + tách nhóm chính thức / cá nhân |
| `lib/modules/channels/application/pairing_controller.dart` | Vòng đời một phiên ghép nối: start → poll → dừng khi nền |
| `lib/modules/channels/application/oauth_watch.dart` | Hàm thuần `firstNewId` |
| `lib/modules/channels/presentation/channels_page.dart` | Danh sách hai nhóm, kết nối lại, ngắt |
| `lib/modules/channels/presentation/connect_sheet.dart` | Bottom sheet chọn kênh |
| `lib/modules/channels/presentation/pair_page.dart` | Trang ghép nối QR |
| `lib/modules/channels/presentation/widgets/channel_tile.dart` | Một thẻ kênh |
| `lib/modules/channels/presentation/widgets/qr_saver.dart` | Giải mã data URL + lưu thư viện |
| `lib/modules/channels/channels_module.dart` | Routes + menu entry + permissions |
| `lib/bootstrap.dart` | Thêm `ChannelsModule()` vào `appModules` |
| `android/app/src/main/AndroidManifest.xml` | Quyền ghi ảnh cho Android ≤ 9 |
| `pubspec.yaml` | Thêm `gal` |

---

### Task 1: Domain — quyền, trạng thái kết nối, cách nối

**Files:**
- Create: `lib/modules/channels/domain/channel_permissions.dart`
- Create: `lib/modules/channels/domain/channel_connection.dart`
- Create: `lib/modules/channels/domain/connectable_channel.dart`
- Test: `test/channels/channel_connection_test.dart`

**Interfaces:**
- Consumes: `Channel`, `ChannelKind`, `ChannelMeta` từ `lib/core/domain/channel.dart`; extension `JsonMap` từ `lib/core/utils/json.dart`.
- Produces:
  - `ChannelPermissions.read` / `.readOwn` / `.write` / `.anyRead` (`List<String>`) / `.all`
  - `enum ChannelStatus { connected, error, disconnected, pending }` với `ChannelStatus.parse(String?)`
  - `class ChannelConnection` — trường `id`, `channel`, `name`, `status`, `today`, `ownerName`, `displayLabel`, `externalAccountId`; getter `label`, `isPersonal`; factory `ChannelConnection.fromJson(Map<String, dynamic>)`
  - `enum ConnectMethod { oauth, pair, none }`, `ConnectableChannels.oauth` / `.pair` (`List<Channel>`), `ConnectableChannels.methodFor(Channel)`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/channels/channel_connection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';
import 'package:omni_app/modules/channels/domain/connectable_channel.dart';

/// Đọc đúng tên trường API thật trả về.
///
/// `ChannelConnectionController::index` bồi thêm `display_label` và `owner_name`
/// vào từng bản ghi, và ghi đè `today` bằng số đếm sống. Nếu client chỉ đọc
/// `name` thì mọi tài khoản cá nhân đều hiện cùng một chữ "Zalo cá nhân" —
/// không phân biệt được tài khoản của ai, đúng thứ màn hình này sinh ra để
/// phân biệt.
void main() {
  group('ChannelConnection.fromJson', () {
    test('lấy display_label làm nhãn hiển thị', () {
      final c = ChannelConnection.fromJson({
        'id': 'c1',
        'channel_id': 'zalo_personal',
        'name': 'Zalo cá nhân',
        'display_label': 'Zalo cá nhân · Kiệt',
        'owner_name': 'Kiệt',
        'status': 'connected',
        'today': 12,
      });

      expect(c.label, 'Zalo cá nhân · Kiệt');
      expect(c.ownerName, 'Kiệt');
      expect(c.today, 12);
      expect(c.channel, Channel.zaloPersonal);
      expect(c.status, ChannelStatus.connected);
      expect(c.isPersonal, isTrue);
    });

    test('thiếu display_label thì lùi về name', () {
      final c = ChannelConnection.fromJson({
        'id': 'c2',
        'channel_id': 'facebook',
        'name': 'Page bán lẻ',
      });

      expect(c.label, 'Page bán lẻ');
      expect(c.isPersonal, isFalse);
    });

    test('thiếu cả hai thì lùi về tên nền tảng, không ra chuỗi rỗng', () {
      final c = ChannelConnection.fromJson({'id': 'c3', 'channel_id': 'tiktok'});

      expect(c.label, Channel.tiktok.meta.name);
    });

    test('trạng thái lạ đọc thành disconnected chứ không nổ', () {
      final c = ChannelConnection.fromJson({
        'id': 'c4',
        'channel_id': 'zalo',
        'status': 'kaboom',
      });

      expect(c.status, ChannelStatus.disconnected);
    });

    test('thiếu today thì là 0', () {
      final c = ChannelConnection.fromJson({'id': 'c5', 'channel_id': 'zalo'});

      expect(c.today, 0);
    });

    test('status pending giữ nguyên — ghép nối dở dang không phải đã ngắt', () {
      final c = ChannelConnection.fromJson({
        'id': 'c6',
        'channel_id': 'zalo_personal',
        'status': 'pending',
      });

      expect(c.status, ChannelStatus.pending);
    });
  });

  group('ConnectableChannels', () {
    test('kênh chính thức đi OAuth', () {
      expect(ConnectableChannels.methodFor(Channel.facebook), ConnectMethod.oauth);
      expect(ConnectableChannels.methodFor(Channel.zalo), ConnectMethod.oauth);
      expect(ConnectableChannels.methodFor(Channel.tiktok), ConnectMethod.oauth);
    });

    test('tài khoản cá nhân đi ghép nối QR', () {
      expect(
        ConnectableChannels.methodFor(Channel.zaloPersonal),
        ConnectMethod.pair,
      );
      expect(
        ConnectableChannels.methodFor(Channel.facebookPersonal),
        ConnectMethod.pair,
      );
    });

    test('kênh không nối được từ app trả về none', () {
      expect(ConnectableChannels.methodFor(Channel.web), ConnectMethod.none);
      expect(ConnectableChannels.methodFor(Channel.unknown), ConnectMethod.none);
    });
  });
}
```

- [ ] **Step 2: Chạy test cho chắc là fail**

Run: `flutter test test/channels/channel_connection_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:omni_app/modules/channels/domain/channel_connection.dart'`

- [ ] **Step 3: Viết `channel_permissions.dart`**

```dart
/// Slug quyền của module kênh, khớp `modules/Channels/Interfaces/routes.php`.
///
/// `read` là toàn tenant, `readOwn` chỉ những tài khoản chính người này ghép
/// nối (`owner_user_id = me`). Server tự cắt danh sách theo slug người dùng
/// giữ, nên client không lọc lại — nó chỉ cần biết ai được *mở màn hình*.
abstract final class ChannelPermissions {
  static const read = 'channels.read';
  static const readOwn = 'channels.read.own';
  static const write = 'channels.write';

  static const anyRead = [read, readOwn];

  static const all = [read, readOwn, write];
}
```

- [ ] **Step 4: Viết `channel_connection.dart`**

```dart
import '../../../core/domain/channel.dart';
import '../../../core/utils/json.dart';

/// Trạng thái của một *kết nối*, khác với [Channel] là *nền tảng*.
///
/// `pending` là một ghép nối đã bắt đầu mà chưa xong — nó KHÁC `disconnected`:
/// gộp hai cái làm một thì một phiên đang chờ người dùng quét QR sẽ hiện y hệt
/// một kênh đã chết, và nút bấm đúng cho hai tình huống đó không giống nhau.
enum ChannelStatus {
  connected,
  error,
  disconnected,
  pending;

  /// Giá trị lạ đọc thành [disconnected]. API là Mongo schema-less và trạng
  /// thái mới có thể xuất hiện trước khi app biết tới — một chuỗi không nhận ra
  /// phải làm màn hình hiện "chưa kết nối", không phải làm nó nổ.
  static ChannelStatus parse(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'connected' => ChannelStatus.connected,
        'error' => ChannelStatus.error,
        'pending' => ChannelStatus.pending,
        _ => ChannelStatus.disconnected,
      };
}

/// Một tài khoản đã nối vào hộp thư.
class ChannelConnection {
  const ChannelConnection({
    required this.id,
    required this.channel,
    required this.name,
    required this.status,
    required this.today,
    this.ownerName,
    this.displayLabel,
    this.externalAccountId,
  });

  factory ChannelConnection.fromJson(Map<String, dynamic> json) {
    return ChannelConnection(
      id: json.strOr('id', ''),
      channel: Channel.parse(json.str('channel_id')),
      name: json.strOr('name', ''),
      status: ChannelStatus.parse(json.str('status')),
      today: json.intOr('today'),
      ownerName: json.str('owner_name'),
      displayLabel: json.str('display_label'),
      externalAccountId: json.str('external_account_id'),
    );
  }

  final String id;
  final Channel channel;
  final String name;
  final ChannelStatus status;
  final int today;

  /// Tên nhân viên sở hữu tài khoản cá nhân này.
  final String? ownerName;

  /// Nhãn server dựng sẵn ("Zalo cá nhân · Kiệt").
  final String? displayLabel;

  final String? externalAccountId;

  /// Nhãn để hiển thị. Ưu tiên nhãn server dựng — nó đã gắn tên chủ tài khoản,
  /// thứ duy nhất phân biệt được hai tài khoản Zalo cá nhân trong cùng workspace.
  String get label {
    final fromServer = displayLabel;
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    if (name.isNotEmpty) return name;
    return channel.meta.name;
  }

  bool get isPersonal => channel.meta.kind == ChannelKind.personal;
}
```

- [ ] **Step 5: Viết `connectable_channel.dart`**

```dart
import '../../../core/domain/channel.dart';

/// Nối kênh này bằng cách nào.
enum ConnectMethod {
  /// Chuyển sang trình duyệt để nền tảng hỏi đồng ý.
  oauth,

  /// Ghép nối với omni-agent bằng QR đăng nhập.
  pair,

  /// Không nối được từ app (website chat, kênh app chưa biết tới).
  none,
}

/// Kênh nào nối được từ app, và bằng cách nào.
///
/// Mọi thứ khác về một kênh — tên, nhãn ngắn, màu, icon, official hay personal
/// — lấy từ [ChannelMeta] trong core. File này chỉ trả lời đúng một câu hỏi core
/// không trả lời được: nối nó ra sao.
abstract final class ConnectableChannels {
  /// Cùng bộ với `connectOptions` bên web client.
  static const oauth = [Channel.facebook, Channel.zalo, Channel.tiktok];

  /// Cùng bộ với `PERSONAL_CHANNELS` trong `ChannelPairingController`.
  static const pair = [Channel.zaloPersonal, Channel.facebookPersonal];

  static ConnectMethod methodFor(Channel channel) {
    if (oauth.contains(channel)) return ConnectMethod.oauth;
    if (pair.contains(channel)) return ConnectMethod.pair;
    return ConnectMethod.none;
  }
}
```

- [ ] **Step 6: Chạy test cho chắc là pass**

Run: `flutter test test/channels/channel_connection_test.dart`
Expected: PASS — 9 test.

- [ ] **Step 7: Phân tích**

Run: `flutter analyze lib/modules/channels test/channels`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/modules/channels/domain test/channels/channel_connection_test.dart
git commit -m "feat(channels): model kết nối kênh và cách nối từng nền tảng"
```

---

### Task 2: Domain — máy trạng thái ghép nối

**Files:**
- Create: `lib/modules/channels/domain/pairing.dart`
- Test: `test/channels/pairing_state_test.dart`

Spec liệt kê `slow_hint_test.dart` thành file riêng. Gộp vào đây thay vì tách:
`shouldShowAgentHint` sống trong cùng `pairing.dart` với `resolvePairing`, và
tách một file test cho năm assert trên một hàm thuần chỉ làm khó việc đọc.

**Interfaces:**
- Consumes: extension `JsonMap`.
- Produces:
  - `class PairingStart` — `connectionId`, `pairingCode`, `expiresAt`; factory `.fromJson`
  - `class PairingStatus` — `status`, `qr`, `stage`, `note`; factory `.fromJson`
  - `enum PairingView { preparing, waiting, qr, scanned, connected, expired, failed }`
  - `class PairingSnapshot` — `view`, `qr`, `stage`, `note`
  - `PairingSnapshot resolvePairing(PairingStatus status)`
  - `bool shouldShowAgentHint({required int ticks, required String? stage, required bool sawQr})`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/channels/pairing_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/channels/domain/pairing.dart';

/// Thứ tự ưu tiên của máy trạng thái ghép nối.
///
/// Server trả về ba tín hiệu độc lập — `status`, `stage`, `qr` — và chúng có
/// thể mâu thuẫn nhau trong cùng một phản hồi. Đọc sai thứ tự thì màn hình
/// hiện một mã QR đã tiêu, hoặc quay spinner trên một phiên server đã bỏ.
void main() {
  group('resolvePairing', () {
    test('connected thắng tất cả', () {
      final s = resolvePairing(const PairingStatus(
        status: 'connected',
        stage: 'qr',
        qr: 'data:image/png;base64,AAAA',
      ));

      expect(s.view, PairingView.connected);
    });

    test('expired thắng mọi stage — server đã bỏ mã, chờ thêm là vô ích', () {
      final s = resolvePairing(const PairingStatus(
        status: 'expired',
        stage: 'qr',
        qr: 'data:image/png;base64,AAAA',
      ));

      expect(s.view, PairingView.expired);
    });

    test('stage error dừng lại và mang theo lời của agent', () {
      final s = resolvePairing(const PairingStatus(
        status: 'pending',
        stage: 'error',
        note: 'Facebook chặn đăng nhập từ máy này',
      ));

      expect(s.view, PairingView.failed);
      expect(s.note, 'Facebook chặn đăng nhập từ máy này');
    });

    test('scanned ẩn QR dù server vẫn trả về ảnh', () {
      final s = resolvePairing(const PairingStatus(
        status: 'pending',
        stage: 'scanned',
        qr: 'data:image/png;base64,AAAA',
      ));

      expect(s.view, PairingView.scanned);
      expect(s.qr, isNull);
    });

    test('có QR và chưa quét thì hiện QR', () {
      final s = resolvePairing(const PairingStatus(
        status: 'pending',
        stage: 'qr',
        qr: 'data:image/png;base64,AAAA',
      ));

      expect(s.view, PairingView.qr);
      expect(s.qr, 'data:image/png;base64,AAAA');
    });

    test('chưa có gì thì là đang chờ, giữ stage để hiện đúng câu mô tả', () {
      final s = resolvePairing(const PairingStatus(
        status: 'pending',
        stage: 'tunnel_pending',
      ));

      expect(s.view, PairingView.waiting);
      expect(s.stage, 'tunnel_pending');
    });

    test('stage null coi như queued', () {
      final s = resolvePairing(const PairingStatus(status: 'pending'));

      expect(s.view, PairingView.waiting);
      expect(s.stage, 'queued');
    });

    test('QR rỗng không tính là có QR', () {
      final s = resolvePairing(const PairingStatus(status: 'pending', qr: ''));

      expect(s.view, PairingView.waiting);
    });
  });

  group('shouldShowAgentHint', () {
    test('đủ 16 nhịp mà vẫn queued và chưa từng thấy QR thì cảnh báo', () {
      expect(
        shouldShowAgentHint(ticks: 16, stage: 'queued', sawQr: false),
        isTrue,
      );
    });

    test('chưa đủ 16 nhịp thì im — 40 giây đầu là chờ bình thường', () {
      expect(
        shouldShowAgentHint(ticks: 15, stage: 'queued', sawQr: false),
        isFalse,
      );
    });

    test('stage khác queued nghĩa là agent đã nhận việc, cảnh báo đó sai', () {
      expect(
        shouldShowAgentHint(ticks: 40, stage: 'logging_in', sawQr: false),
        isFalse,
      );
    });

    test('đã từng thấy QR thì agent chắc chắn đang chạy', () {
      expect(
        shouldShowAgentHint(ticks: 40, stage: 'queued', sawQr: true),
        isFalse,
      );
    });

    test('stage null coi như queued', () {
      expect(shouldShowAgentHint(ticks: 20, stage: null, sawQr: false), isTrue);
    });
  });

  group('PairingStatus.fromJson', () {
    test('đọc đúng bốn trường server trả về', () {
      final s = PairingStatus.fromJson({
        'status': 'pending',
        'qr': 'data:image/png;base64,AAAA',
        'stage': 'qr',
        'note': null,
      });

      expect(s.status, 'pending');
      expect(s.qr, 'data:image/png;base64,AAAA');
      expect(s.stage, 'qr');
      expect(s.note, isNull);
    });
  });

  group('PairingStart.fromJson', () {
    test('đọc connection_id và pairing_code', () {
      final s = PairingStart.fromJson({
        'connection_id': 'abc123',
        'channel_id': 'zalo_personal',
        'pairing_code': 'K7M2X9QP',
        'expires_at': '2026-08-04T12:30:00Z',
      });

      expect(s.connectionId, 'abc123');
      expect(s.pairingCode, 'K7M2X9QP');
      expect(s.expiresAt, '2026-08-04T12:30:00Z');
    });
  });
}
```

- [ ] **Step 2: Chạy test cho chắc là fail**

Run: `flutter test test/channels/pairing_state_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../domain/pairing.dart'`

- [ ] **Step 3: Viết `pairing.dart`**

```dart
import '../../../core/utils/json.dart';

/// Số nhịp poll trước khi kết luận không có máy nào chạy agent.
/// 16 nhịp × 2,5 giây ≈ 40 giây.
const pairingAgentHintTicks = 16;

/// Nhịp poll trạng thái ghép nối. Bằng web: agent đẩy QR lên theo nhịp riêng
/// của nó, poll dày hơn không nhận được sớm hơn, chỉ tốn pin và data.
const pairingPollInterval = Duration(milliseconds: 2500);

/// Kết quả `POST /channels/pair/start`.
class PairingStart {
  const PairingStart({
    required this.connectionId,
    required this.pairingCode,
    required this.expiresAt,
  });

  factory PairingStart.fromJson(Map<String, dynamic> json) => PairingStart(
        connectionId: json.strOr('connection_id', ''),
        pairingCode: json.strOr('pairing_code', ''),
        expiresAt: json.strOr('expires_at', ''),
      );

  final String connectionId;
  final String pairingCode;
  final String expiresAt;
}

/// Kết quả `GET /channels/pair/{id}/status`, nguyên như server trả.
class PairingStatus {
  const PairingStatus({required this.status, this.qr, this.stage, this.note});

  factory PairingStatus.fromJson(Map<String, dynamic> json) => PairingStatus(
        status: json.strOr('status', 'pending'),
        qr: json.str('qr'),
        stage: json.str('stage'),
        note: json.str('note'),
      );

  /// `pending` | `connected` | `expired` | `error` | `disconnected`.
  final String status;

  /// Ảnh QR dạng data URL, do agent đẩy lên. Sống khoảng 100 giây.
  final String? qr;

  /// `queued` | `logging_in` | `qr` | `scanned` | `tunnel_pending` | `error`.
  final String? stage;

  /// Lời của chính agent khi nó hỏng. Nó biết chuyện gì xảy ra, app thì không.
  final String? note;
}

/// Cái màn hình ghép nối đang phải hiện.
enum PairingView { preparing, waiting, qr, scanned, connected, expired, failed }

class PairingSnapshot {
  const PairingSnapshot({required this.view, this.qr, this.stage, this.note});

  final PairingView view;

  /// Chỉ khác null khi [view] là [PairingView.qr].
  final String? qr;

  final String? stage;
  final String? note;
}

/// Gộp ba tín hiệu độc lập của server thành một trạng thái màn hình.
///
/// Hàm thuần, cố ý: đây là chỗ duy nhất quyết định người dùng nhìn thấy gì, và
/// nó phải test được mà không cần dựng widget hay giả lập mạng.
///
/// Thứ tự ưu tiên không tuỳ tiện. `connected` và `expired` là kết thúc, chúng
/// thắng mọi stage còn sót lại trong cùng phản hồi. `scanned` phải ẩn QR dù
/// server vẫn trả ảnh — mã đã tiêu rồi, hiện lại chỉ mời người ta quét lần hai.
PairingSnapshot resolvePairing(PairingStatus status) {
  final stage = status.stage ?? 'queued';
  final qr = status.qr;

  if (status.status == 'connected') {
    return const PairingSnapshot(view: PairingView.connected);
  }
  if (status.status == 'expired') {
    return const PairingSnapshot(view: PairingView.expired);
  }
  if (stage == 'error') {
    return PairingSnapshot(
      view: PairingView.failed,
      stage: stage,
      note: status.note,
    );
  }
  if (stage == 'scanned') {
    return PairingSnapshot(view: PairingView.scanned, stage: stage);
  }
  if (qr != null && qr.isNotEmpty) {
    return PairingSnapshot(view: PairingView.qr, qr: qr, stage: stage);
  }
  return PairingSnapshot(view: PairingView.waiting, stage: stage);
}

/// Có nên nói "hình như không máy nào chạy agent" chưa.
///
/// Chỉ đúng khi stage vẫn `queued`: mọi stage khác nghĩa là agent ĐÃ nhận việc,
/// lúc đó câu này sai và đẩy người dùng đi sửa nhầm chỗ.
bool shouldShowAgentHint({
  required int ticks,
  required String? stage,
  required bool sawQr,
}) {
  if (sawQr) return false;
  if (ticks < pairingAgentHintTicks) return false;
  return (stage ?? 'queued') == 'queued';
}
```

- [ ] **Step 4: Chạy test cho chắc là pass**

Run: `flutter test test/channels/pairing_state_test.dart`
Expected: PASS — 15 test.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/channels/domain/pairing.dart test/channels/pairing_state_test.dart
git commit -m "feat(channels): máy trạng thái ghép nối tách thành hàm thuần"
```

---

### Task 3: Data + module đăng ký + màn hình danh sách

Deliverable: mở app, vào "Thêm" → "Kết nối kênh" thấy danh sách kênh thật.

**Files:**
- Create: `lib/modules/channels/data/channels_api.dart`
- Create: `lib/modules/channels/application/channels_providers.dart`
- Create: `lib/modules/channels/presentation/widgets/channel_tile.dart`
- Create: `lib/modules/channels/presentation/channels_page.dart`
- Create: `lib/modules/channels/channels_module.dart`
- Modify: `lib/bootstrap.dart` (danh sách `appModules`)
- Test: `test/channels/channels_module_test.dart`

**Interfaces:**
- Consumes: `ChannelConnection`, `ChannelStatus`, `ChannelPermissions` (Task 1); `PairingStart`, `PairingStatus` (Task 2); `apiClientProvider` từ `lib/core/network/api_client.dart`; `AppConfig.maxPerPage`.
- Produces:
  - `ChannelsApi` với `list()`, `disconnect(String id)`, `oauthUrl(Channel)`, `pairStart(Channel, {bool forceRelogin})`, `pairStatus(String connectionId)`; provider `channelsApiProvider`
  - `channelsProvider` (`FutureProvider<List<ChannelConnection>>`)
  - `ChannelTile` widget
  - `ChannelsModule` với hằng `ChannelsModule.list` = `'channels.list'`, `ChannelsModule.pair` = `'channels.pair'`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/channels/channels_module_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/modules/channels/domain/channel_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Màn kết nối kênh phải xuất hiện đúng theo quyền, và không bao giờ chiếm tab.
///
/// Nó là màn thao tác một lần rồi thôi. Cho nó một tab là lấy chỗ của màn dùng
/// hàng ngày; giấu nó khỏi người có quyền là khiến họ tưởng app thiếu chức năng.
ProviderContainer _containerFor(Set<String> permissions) {
  return ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(appModules),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy(permissions),
        ),
      ),
    ],
  );
}

List<String> _menuLabels(ProviderContainer container) => container
    .read(visibleMenuEntriesProvider)
    .values
    .expand((entries) => entries)
    .map((entry) => entry.label)
    .toList();

void main() {
  test('người có channels.read thấy mục Kết nối kênh', () {
    final container = _containerFor({ChannelPermissions.read});
    addTearDown(container.dispose);

    expect(_menuLabels(container), contains('Kết nối kênh'));
  });

  test('nhân viên chỉ có channels.read.own vẫn vào được', () {
    final container = _containerFor({ChannelPermissions.readOwn});
    addTearDown(container.dispose);

    expect(_menuLabels(container), contains('Kết nối kênh'));
  });

  test('không có quyền kênh thì không thấy mục nào', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    expect(_menuLabels(container), isNot(contains('Kết nối kênh')));
  });

  test('mục này nằm trong nhóm Quản trị', () {
    final container = _containerFor({ChannelPermissions.read});
    addTearDown(container.dispose);

    final admin = container.read(visibleMenuEntriesProvider)['Quản trị'] ?? [];
    expect(admin.map((e) => e.label), contains('Kết nối kênh'));
  });

  test('kênh không chiếm tab dưới', () {
    final container = _containerFor(ChannelPermissions.all.toSet());
    addTearDown(container.dispose);

    final labels =
        container.read(visibleDestinationsProvider).map((d) => d.label);
    expect(labels, isNot(contains('Kết nối kênh')));
  });
}
```

- [ ] **Step 2: Chạy test cho chắc là fail**

Run: `flutter test test/channels/channels_module_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../domain/channel_permissions.dart'` chưa được import ở bootstrap, và không tìm thấy nhãn 'Kết nối kênh'.

- [ ] **Step 3: Viết `channels_api.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/channel.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../domain/channel_connection.dart';
import '../domain/pairing.dart';

/// Chỗ duy nhất trong app viết đường dẫn `/channels/...`.
///
/// Đường dẫn tương đối với `/api/v1` — [ApiClient] tự thêm tiền tố, nên không
/// nơi nào lặp lại phiên bản API.
class ChannelsApi {
  ChannelsApi(this._client);

  final ApiClient _client;

  Future<List<ChannelConnection>> list() async {
    final response = await _client.get(
      '/channels',
      query: {'per_page': AppConfig.maxPerPage},
    );
    return response.list.map(ChannelConnection.fromJson).toList();
  }

  Future<void> disconnect(String id) => _client.delete('/channels/$id');

  /// URL trang đồng ý của nền tảng. Mở bằng trình duyệt ngoài — Facebook và
  /// Google chặn webview nhúng cho đăng nhập.
  Future<String> oauthUrl(Channel channel) async {
    final response = await _client.get('/channels/${channel.slug}/oauth/redirect');
    return response.object.strOr('authorization_url', '');
  }

  /// Mở một phiên ghép nối mới.
  ///
  /// [forceRelogin] bảo agent vứt phiên đăng nhập nó đang giữ cho kênh này và
  /// hiện QR mới. Không có cờ này thì lần ghép nối thứ hai chỉ nối lại đúng tài
  /// khoản cũ — đúng cho việc nối lại, sai khi người dùng muốn đổi tài khoản.
  Future<PairingStart> pairStart(
    Channel channel, {
    bool forceRelogin = false,
  }) async {
    final response = await _client.post(
      '/channels/pair/start',
      body: {'channel_id': channel.slug, 'force_relogin': forceRelogin},
    );
    return PairingStart.fromJson(response.object);
  }

  Future<PairingStatus> pairStatus(String connectionId) async {
    final response = await _client.get('/channels/pair/$connectionId/status');
    return PairingStatus.fromJson(response.object);
  }
}

final channelsApiProvider =
    Provider<ChannelsApi>((ref) => ChannelsApi(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Viết `channels_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channels_api.dart';
import '../domain/channel_connection.dart';

/// Danh sách kênh của workspace. Server đã cắt theo quyền (`channels.read` toàn
/// tenant, `channels.read.own` chỉ tài khoản mình ghép) nên client không lọc lại.
final channelsProvider = FutureProvider<List<ChannelConnection>>((ref) {
  return ref.watch(channelsApiProvider).list();
});
```

- [ ] **Step 5: Viết `widgets/channel_tile.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/channel_connection.dart';

/// Một kênh trong danh sách.
///
/// Trạng thái hiện bằng chữ kèm màu, không bằng màu suông — một chấm đỏ không
/// nói được "đang chờ ghép nối" khác "đăng nhập hỏng" ở chỗ nào, mà hai cái đó
/// cần hai hành động khác nhau.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.connection,
    required this.canWrite,
    required this.onReconnect,
    required this.onDisconnect,
  });

  final ChannelConnection connection;
  final bool canWrite;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

  static const _statusLabels = {
    ChannelStatus.connected: ('Đang hoạt động', OmniTone.success),
    ChannelStatus.error: ('Lỗi kết nối', OmniTone.danger),
    ChannelStatus.pending: ('Đang chờ ghép nối', OmniTone.warning),
    ChannelStatus.disconnected: ('Chưa kết nối', OmniTone.neutral),
  };

  bool get _needsReconnect =>
      connection.status == ChannelStatus.error ||
      connection.status == ChannelStatus.disconnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = connection.channel.meta;
    final (statusLabel, tone) =
        _statusLabels[connection.status] ?? ('Chưa kết nối', OmniTone.neutral);

    return OmniCard(
      padding: const EdgeInsets.all(OmniSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.tint,
              borderRadius: OmniRadius.smAll,
            ),
            child: Icon(meta.icon, size: 20, color: meta.color),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.label,
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Row(
                  children: [
                    OmniStatusChip(label: statusLabel, tone: tone),
                    const SizedBox(width: OmniSpacing.sm),
                    Text(
                      '${connection.today} tin hôm nay',
                      style: OmniType.micro
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                if (_needsReconnect) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  TextButton.icon(
                    onPressed: canWrite ? onReconnect : null,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Kết nối lại'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: canWrite ? onDisconnect : null,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Ngắt kết nối',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Viết `channels_page.dart`**

Nút "Kết nối kênh" gọi `showConnectSheet` — Task 4 tạo. Ở bước này để nó hiện snackbar tạm để màn hình chạy được độc lập; Task 4 thay bằng lời gọi thật.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/channels_providers.dart';
import '../data/channels_api.dart';
import '../domain/channel_connection.dart';
import '../domain/channel_permissions.dart';
import 'widgets/channel_tile.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    ChannelConnection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ngắt kết nối?'),
        content: Text(
          '${connection.label} sẽ ngừng nhận tin về hộp thư. '
          'Nối lại được bất cứ lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(channelsApiProvider).disconnect(connection.id);
      ref.invalidate(channelsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã ngắt ${connection.label}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final canWrite = ref.watch(accessProvider).can(ChannelPermissions.write);

    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối kênh')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canWrite
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chọn kênh — sắp có')),
                )
            : null,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Kết nối kênh'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(channelsProvider),
        child: OmniAsyncView(
          value: channels,
          onRetry: () => ref.invalidate(channelsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.hub_outlined,
            title: 'Chưa nối kênh nào',
            message:
                'Nối Zalo, Facebook hoặc TikTok để tin nhắn khách đổ về hộp thư.',
          ),
          data: (list) {
            final official = list.where((c) => !c.isPersonal).toList();
            final personal = list.where((c) => c.isPersonal).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.xxl,
              ),
              children: [
                if (official.isNotEmpty) ...[
                  const OmniSectionHeader(
                    title: 'Kênh chính thức',
                    // ListView đã có gutter lg; padding mặc định của header là
                    // lg hai bên + xxl trên, cộng vào là thụt hai lần.
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (final connection in official) ...[
                    ChannelTile(
                      connection: connection,
                      canWrite: canWrite,
                      onReconnect: () {},
                      onDisconnect: () => _disconnect(context, ref, connection),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                  ],
                ],
                if (personal.isNotEmpty) ...[
                  const SizedBox(height: OmniSpacing.md),
                  const OmniSectionHeader(
                    title: 'Tài khoản cá nhân',
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (final connection in personal) ...[
                    ChannelTile(
                      connection: connection,
                      canWrite: canWrite,
                      onReconnect: () {},
                      onDisconnect: () => _disconnect(context, ref, connection),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
```

`OmniSectionHeader` có sẵn tham số `padding` (mặc định lg hai bên, xxl trên) — ghi đè như trên chứ đừng thêm biến thể component mới.

- [ ] **Step 7: Viết `channels_module.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/channel_permissions.dart';
import 'presentation/channels_page.dart';

/// Nối tài khoản nhắn tin vào hộp thư.
///
/// Không nhận tab: đây là màn thao tác một lần rồi thôi, không phải màn làm
/// việc hàng ngày. Nó sống trong "Thêm", nhóm Quản trị, cạnh "Nhân viên".
class ChannelsModule extends OmniModule {
  const ChannelsModule();

  static const list = 'channels.list';

  @override
  String get id => 'channels';

  @override
  String get title => 'Kênh';

  @override
  List<String> get permissions => ChannelPermissions.all;

  @override
  List<ModuleRoute> routes() => [
        ModuleRoute(
          path: '/channels',
          name: list,
          rootNavigator: true,
          access: const AccessRequirement.any(ChannelPermissions.anyRead),
          builder: (_, _) => const ChannelsPage(),
        ),
      ];

  @override
  List<ModuleMenuEntry> menuEntries() => const [
        ModuleMenuEntry(
          moduleId: 'channels',
          label: 'Kết nối kênh',
          subtitle: 'Nối Zalo, Facebook, TikTok vào hộp thư',
          icon: Icons.hub_outlined,
          routeName: list,
          group: 'Quản trị',
          order: 20,
          access: AccessRequirement.any(ChannelPermissions.anyRead),
        ),
      ];
}
```

- [ ] **Step 8: Đăng ký module trong `bootstrap.dart`**

Thêm import và một dòng vào `appModules`, ngay sau `TeamModule()`:

```dart
import 'modules/channels/channels_module.dart';
```

```dart
const List<OmniModule> appModules = [
  AuthModule(),
  InboxModule(),
  CustomersModule(),
  OpportunitiesModule(),
  TeamModule(),
  ChannelsModule(),
  SettingsModule(),
];
```

- [ ] **Step 9: Chạy test cho chắc là pass**

Run: `flutter test test/channels/`
Expected: PASS — cả 3 file test.

- [ ] **Step 10: Phân tích**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add lib/modules/channels lib/bootstrap.dart test/channels/channels_module_test.dart
git commit -m "feat(channels): màn hình danh sách kênh vào từ Thêm/Quản trị"
```

---

### Task 4: Chọn kênh + nối kênh chính thức qua OAuth

**Files:**
- Create: `lib/modules/channels/application/oauth_watch.dart`
- Create: `lib/modules/channels/presentation/connect_sheet.dart`
- Modify: `lib/modules/channels/presentation/channels_page.dart` (thay snackbar tạm bằng sheet thật; nối `onReconnect`)
- Test: `test/channels/oauth_watch_test.dart`

**Interfaces:**
- Consumes: `ConnectableChannels`, `ConnectMethod` (Task 1); `channelsApiProvider`, `channelsProvider` (Task 3); `ChannelsModule.pair` (Task 5 tạo — ở bước này chưa gọi tới).
- Produces:
  - `String? firstNewId(Set<String> before, List<ChannelConnection> now)`
  - `Future<Channel?> showConnectSheet(BuildContext context)` — trả kênh người dùng chọn, `null` nếu đóng sheet

- [ ] **Step 1: Viết test thất bại**

Tạo `test/channels/oauth_watch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/channels/application/oauth_watch.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';

/// Nhận ra kênh vừa nối xong khi người dùng quay về từ trình duyệt.
///
/// Callback OAuth đáp xuống web chứ không về app, nên app không được báo. Cách
/// duy nhất biết là so danh sách trước và sau. So bằng số lượng thì sai: một
/// kênh khác bị ngắt trong lúc đó sẽ giữ nguyên tổng và app im lặng mãi.
ChannelConnection _connection(String id) =>
    ChannelConnection.fromJson({'id': id, 'channel_id': 'facebook'});

void main() {
  test('trả về id chưa từng thấy', () {
    final id = firstNewId(
      {'a', 'b'},
      [_connection('a'), _connection('b'), _connection('c')],
    );

    expect(id, 'c');
  });

  test('không có gì mới thì trả null', () {
    final id = firstNewId({'a', 'b'}, [_connection('a'), _connection('b')]);

    expect(id, isNull);
  });

  test('một kênh biến mất không bị nhầm là kênh mới', () {
    final id = firstNewId({'a', 'b'}, [_connection('a')]);

    expect(id, isNull);
  });

  test('vừa mất một vừa thêm một vẫn nhận ra cái mới', () {
    final id = firstNewId({'a', 'b'}, [_connection('a'), _connection('z')]);

    expect(id, 'z');
  });

  test('danh sách trước rỗng thì kênh đầu tiên là mới', () {
    final id = firstNewId({}, [_connection('a')]);

    expect(id, 'a');
  });
}
```

- [ ] **Step 2: Chạy test cho chắc là fail**

Run: `flutter test test/channels/oauth_watch_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../application/oauth_watch.dart'`

- [ ] **Step 3: Viết `oauth_watch.dart`**

```dart
import '../domain/channel_connection.dart';

/// Bao lâu thì bỏ cuộc chờ người dùng xong OAuth bên trình duyệt.
const oauthWatchTimeout = Duration(minutes: 3);

/// Bao lâu gọi lại danh sách một lần trong lúc chờ.
const oauthWatchInterval = Duration(seconds: 3);

/// Id kết nối xuất hiện sau khi rời app, hoặc null nếu chưa có gì mới.
///
/// So theo tập id chứ không theo số lượng: nếu trong lúc chờ có một kênh khác
/// bị ngắt thì tổng số không đổi, và app sẽ chờ mãi một sự kiện đã xảy ra rồi.
String? firstNewId(Set<String> before, List<ChannelConnection> now) {
  for (final connection in now) {
    if (!before.contains(connection.id)) return connection.id;
  }
  return null;
}
```

- [ ] **Step 4: Chạy test cho chắc là pass**

Run: `flutter test test/channels/oauth_watch_test.dart`
Expected: PASS — 5 test.

- [ ] **Step 5: Viết `connect_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../core/domain/channel.dart';
import '../../../design/tokens/tokens.dart';
import '../domain/connectable_channel.dart';

/// Chọn kênh muốn nối. Trả kênh đã chọn, hoặc null nếu người dùng đóng sheet.
///
/// Sheet là đúng ở đây và chỉ ở đây: chọn xong nó đóng ngay, không có tiến
/// trình nào đang sống để mất khi vuốt nhầm. Việc ghép nối thì ngược lại — nó
/// đi sang một trang riêng.
Future<Channel?> showConnectSheet(BuildContext context) {
  return showModalBottomSheet<Channel>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          0,
          OmniSpacing.lg,
          OmniSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kênh chính thức', style: OmniType.bodyStrong),
            Text(
              'Nói danh nghĩa công ty. Nối bằng cách đăng nhập trên trình duyệt.',
              style: OmniType.micro.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            for (final channel in ConnectableChannels.oauth)
              _ChannelOption(channel: channel),
            const SizedBox(height: OmniSpacing.lg),
            Text('Tài khoản cá nhân', style: OmniType.bodyStrong),
            Text(
              'Tài khoản riêng của nhân viên. Cần một máy tính đang chạy '
              'omni-agent để quét mã đăng nhập.',
              style: OmniType.micro.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            for (final channel in ConnectableChannels.pair)
              _ChannelOption(channel: channel),
          ],
        ),
      ),
    ),
  );
}

class _ChannelOption extends StatelessWidget {
  const _ChannelOption({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final meta = channel.meta;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: meta.tint, borderRadius: OmniRadius.smAll),
        child: Icon(meta.icon, size: 20, color: meta.color),
      ),
      title: Text(meta.name),
      onTap: () => Navigator.of(context).pop(channel),
    );
  }
}
```

- [ ] **Step 6: Nối OAuth vào `channels_page.dart`**

Thêm import:

```dart
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/channel.dart';
import '../application/oauth_watch.dart';
import '../domain/connectable_channel.dart';
import 'connect_sheet.dart';
```

Đổi `ChannelsPage` từ `ConsumerWidget` sang `ConsumerStatefulWidget` (cần huỷ timer khi rời màn hình), và thêm hai hàm:

```dart
class ChannelsPage extends ConsumerStatefulWidget {
  const ChannelsPage({super.key});

  @override
  ConsumerState<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends ConsumerState<ChannelsPage> {
  Timer? _oauthWatch;
  bool _connecting = false;

  @override
  void dispose() {
    _oauthWatch?.cancel();
    super.dispose();
  }

  Future<void> _pickChannel() async {
    final channel = await showConnectSheet(context);
    if (channel == null || !mounted) return;

    switch (ConnectableChannels.methodFor(channel)) {
      case ConnectMethod.oauth:
        await _startOauth(channel);
      case ConnectMethod.pair:
        // Task 5 nối vào trang ghép nối.
        break;
      case ConnectMethod.none:
        break;
    }
  }

  /// Mở trình duyệt ngoài rồi dò danh sách tới khi thấy kết nối mới.
  ///
  /// Callback OAuth đáp xuống web chứ không quay về app, nên đây là cách duy
  /// nhất biết người dùng đã xong: so tập id trước và sau.
  Future<void> _startOauth(Channel channel) async {
    setState(() => _connecting = true);
    try {
      final url = await ref.read(channelsApiProvider).oauthUrl(channel);
      if (url.isEmpty) throw Exception('Nền tảng chưa cấu hình OAuth.');

      final before = {
        for (final c in ref.read(channelsProvider).valueOrNull ?? const [])
          c.id,
      };

      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Không mở được trình duyệt.');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập xong thì quay lại đây, app tự nhận.'),
          duration: Duration(seconds: 6),
        ),
      );
      _watchForConnection(before);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _watchForConnection(Set<String> before) {
    _oauthWatch?.cancel();
    final startedAt = DateTime.now();

    _oauthWatch = Timer.periodic(oauthWatchInterval, (timer) async {
      if (DateTime.now().difference(startedAt) > oauthWatchTimeout) {
        timer.cancel();
        return;
      }
      try {
        final fresh = await ref.read(channelsApiProvider).list();
        if (firstNewId(before, fresh) == null) return;

        timer.cancel();
        ref.invalidate(channelsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nối kênh mới.')),
        );
      } catch (_) {
        // Rớt mạng một nhịp không được giết cả phiên chờ.
      }
    });
  }
```

Thêm `import 'dart:async';` ở đầu file. Chuyển phần `build` sang `Widget build(BuildContext context)` của `ConsumerState` (dùng `ref` trực tiếp, bỏ tham số `WidgetRef`), và đổi `onPressed` của FAB thành `_connecting ? null : (canWrite ? _pickChannel : null)`. Đổi `onReconnect` của mỗi `ChannelTile`: kênh chính thức gọi `_startOauth(connection.channel)`, kênh cá nhân để trống ở bước này (Task 5 nối).

- [ ] **Step 7: Chạy toàn bộ test**

Run: `flutter test`
Expected: PASS toàn bộ.

- [ ] **Step 8: Phân tích**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/modules/channels test/channels/oauth_watch_test.dart
git commit -m "feat(channels): chọn kênh và nối kênh chính thức qua trình duyệt ngoài"
```

---

### Task 5: Trang ghép nối QR + vòng poll theo vòng đời app

**Files:**
- Create: `lib/modules/channels/application/pairing_controller.dart`
- Create: `lib/modules/channels/presentation/pair_page.dart`
- Modify: `lib/modules/channels/channels_module.dart` (thêm route `pair`)
- Modify: `lib/modules/channels/presentation/channels_page.dart` (mở trang ghép nối)

**Interfaces:**
- Consumes: `resolvePairing`, `shouldShowAgentHint`, `PairingView`, `PairingSnapshot`, `pairingPollInterval` (Task 2); `channelsApiProvider` (Task 3).
- Produces:
  - `class PairingState` — `snapshot`, `connectionId`, `showAgentHint`, `errorMessage`
  - `PairingController` với `start({bool forceRelogin})`, `pause()`, `resume()`
  - `pairingControllerProvider` (`NotifierProvider.autoDispose.family<PairingController, PairingState, Channel>`)
  - `ChannelsModule.pair` = `'channels.pair'`, route `/channels/pair/:channelId`

- [ ] **Step 1: Viết `pairing_controller.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/channel.dart';
import '../data/channels_api.dart';
import '../domain/pairing.dart';

class PairingState {
  const PairingState({
    required this.snapshot,
    this.connectionId,
    this.showAgentHint = false,
    this.errorMessage,
  });

  final PairingSnapshot snapshot;
  final String? connectionId;

  /// Đã đủ lâu mà agent chưa hề nhận việc.
  final bool showAgentHint;

  /// Lỗi của chính app (mạng, API), khác với `snapshot.note` là lỗi của agent.
  final String? errorMessage;

  PairingState copyWith({
    PairingSnapshot? snapshot,
    String? connectionId,
    bool? showAgentHint,
    String? errorMessage,
  }) {
    return PairingState(
      snapshot: snapshot ?? this.snapshot,
      connectionId: connectionId ?? this.connectionId,
      showAgentHint: showAgentHint ?? this.showAgentHint,
      errorMessage: errorMessage,
    );
  }
}

/// Vòng đời một phiên ghép nối: mở mã → dò trạng thái → dừng khi xong.
///
/// Poll dừng hẳn khi app xuống nền và chạy lại ngay khi quay lên. Người dùng
/// BẮT BUỘC rời app sang Zalo để quét ảnh QR, nên đây là đường đi thường gặp
/// chứ không phải trường hợp hiếm — không xử lý thì Android bóp timer nền và
/// quay lại app thấy màn hình đứng nguyên dù server đã nối xong.
class PairingController extends AutoDisposeFamilyNotifier<PairingState, Channel> {
  Timer? _timer;
  int _ticks = 0;
  bool _sawQr = false;

  @override
  PairingState build(Channel arg) {
    ref.onDispose(_stop);
    return const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );
  }

  /// Mở một phiên mới. [forceRelogin] bảo agent quên tài khoản nó đang giữ.
  Future<void> start({bool forceRelogin = false}) async {
    _stop();
    _ticks = 0;
    _sawQr = false;
    state = const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );

    try {
      final started = await ref
          .read(channelsApiProvider)
          .pairStart(arg, forceRelogin: forceRelogin);

      state = PairingState(
        snapshot: const PairingSnapshot(
          view: PairingView.waiting,
          stage: 'queued',
        ),
        connectionId: started.connectionId,
      );
      _startPolling();
    } catch (error) {
      state = PairingState(
        snapshot: const PairingSnapshot(view: PairingView.failed),
        errorMessage: '$error',
      );
    }
  }

  void pause() => _timer?.cancel();

  /// Poll ngay một nhịp trước khi hẹn giờ lại — trong lúc app ở nền, phiên có
  /// thể đã nối xong, và bắt người dùng nhìn màn hình cũ thêm 2,5 giây nữa là
  /// đủ để họ tưởng hỏng.
  void resume() {
    if (_isFinished || state.connectionId == null) return;
    unawaited(_poll());
    _startPolling();
  }

  bool get _isFinished => switch (state.snapshot.view) {
        PairingView.connected ||
        PairingView.expired ||
        PairingView.failed =>
          true,
        _ => false,
      };

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pairingPollInterval, (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final id = state.connectionId;
    if (id == null) return;

    _ticks++;
    try {
      final status = await ref.read(channelsApiProvider).pairStatus(id);
      final snapshot = resolvePairing(status);
      if (snapshot.view == PairingView.qr) _sawQr = true;

      state = state.copyWith(
        snapshot: snapshot,
        showAgentHint: shouldShowAgentHint(
          ticks: _ticks,
          stage: snapshot.stage,
          sawQr: _sawQr,
        ),
      );

      if (_isFinished) _stop();
    } catch (_) {
      // Lỗi lẻ tẻ khi poll thì nuốt và đi tiếp. Rớt sóng hai giây không được
      // giết một phiên ghép nối sống ba mươi phút.
    }
  }
}

final pairingControllerProvider = NotifierProvider.autoDispose
    .family<PairingController, PairingState, Channel>(PairingController.new);
```

- [ ] **Step 2: Kiểm tra biên dịch**

Run: `flutter analyze lib/modules/channels/application/pairing_controller.dart`
Expected: `No issues found!`

Nếu Riverpod báo sai kiểu ở `AutoDisposeFamilyNotifier`, tra chữ ký thật của phiên bản đang cài bằng `grep -rn "class AutoDisposeFamilyNotifier" ~/AppData/Local/Pub/Cache/hosted/pub.dev/riverpod-*/lib/` rồi khớp theo — không đổi sang StateNotifier.

- [ ] **Step 3: Viết `pair_page.dart`**

Nút "Lưu ảnh QR" ở bước này chỉ hiện snackbar; Task 6 nối vào hàm lưu thật.

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/channels_providers.dart';
import '../application/pairing_controller.dart';
import '../domain/pairing.dart';

class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key, required this.channel});

  final Channel channel;

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pairingControllerProvider(widget.channel).notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Người dùng rời app sang Zalo để quét ảnh QR là đường đi bình thường của
  /// màn này, không phải ngoại lệ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller =
        ref.read(pairingControllerProvider(widget.channel).notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        controller.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pairingControllerProvider(widget.channel));
    final controller =
        ref.read(pairingControllerProvider(widget.channel).notifier);
    final meta = widget.channel.meta;

    ref.listen(pairingControllerProvider(widget.channel), (previous, next) {
      if (next.snapshot.view != PairingView.connected) return;
      ref.invalidate(channelsProvider);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text('Ghép nối ${meta.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _body(context, state, controller),
              const SizedBox(height: OmniSpacing.xl),
              if (_canSwitchAccount(state.snapshot.view))
                TextButton(
                  onPressed: () => controller.start(forceRelogin: true),
                  child: const Text('Đăng nhập tài khoản khác'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ba lúc người dùng còn kịp nhận ra agent vừa nối lại đúng tài khoản cũ chứ
  /// không phải tài khoản họ định đổi sang.
  bool _canSwitchAccount(PairingView view) => switch (view) {
        PairingView.waiting || PairingView.qr || PairingView.connected => true,
        _ => false,
      };

  Widget _body(
    BuildContext context,
    PairingState state,
    PairingController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;

    switch (state.snapshot.view) {
      case PairingView.preparing:
      case PairingView.waiting:
        return Column(
          children: [
            const SizedBox(height: OmniSpacing.xl),
            const CircularProgressIndicator(),
            const SizedBox(height: OmniSpacing.lg),
            Text(_waitingMessage(state.snapshot.stage), style: OmniType.body),
            if (state.showAgentHint) ...[
              const SizedBox(height: OmniSpacing.md),
              Text(
                'Hình như chưa có máy tính nào đang chạy omni-agent. '
                'Mở agent trên máy trực 24/7 rồi thử lại.',
                textAlign: TextAlign.center,
                style: OmniType.micro.copyWith(color: OmniColors.warning),
              ),
            ],
          ],
        );

      case PairingView.qr:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(OmniSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: OmniRadius.mdAll,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Image.memory(
                _decodeQr(state.snapshot.qr!),
                width: 280,
                height: 280,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lưu ảnh — sắp có')),
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Lưu ảnh QR'),
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(
              'Lưu ảnh → mở ${widget.channel.meta.short} → Quét mã QR → '
              'chọn ảnh vừa lưu trong thư viện.',
              textAlign: TextAlign.center,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              'Mã đổi sau khoảng 100 giây — lưu xong quét luôn.',
              textAlign: TextAlign.center,
              style: OmniType.micro.copyWith(color: OmniColors.warning),
            ),
          ],
        );

      case PairingView.scanned:
        return Column(
          children: [
            const SizedBox(height: OmniSpacing.xl),
            const CircularProgressIndicator(),
            const SizedBox(height: OmniSpacing.lg),
            Text('Đã quét. Mở app và bấm Đồng ý.', style: OmniType.bodyStrong),
          ],
        );

      case PairingView.connected:
        return Column(
          children: [
            const SizedBox(height: OmniSpacing.xl),
            Icon(Icons.check_circle_rounded,
                size: 48, color: OmniColors.success),
            const SizedBox(height: OmniSpacing.md),
            Text('Đã kết nối!', style: OmniType.bodyStrong),
          ],
        );

      case PairingView.expired:
        return _problem(
          context,
          'Mã ghép nối đã hết hạn.',
          controller,
        );

      case PairingView.failed:
        return _problem(
          context,
          state.snapshot.note ?? state.errorMessage ?? 'Không kết nối được.',
          controller,
        );
    }
  }

  Widget _problem(
    BuildContext context,
    String message,
    PairingController controller,
  ) {
    return Column(
      children: [
        const SizedBox(height: OmniSpacing.xl),
        Icon(Icons.error_outline_rounded,
            size: 40, color: OmniColors.destructive),
        const SizedBox(height: OmniSpacing.md),
        Text(message, textAlign: TextAlign.center, style: OmniType.body),
        const SizedBox(height: OmniSpacing.lg),
        FilledButton(
          onPressed: () => controller.start(),
          child: const Text('Thử lại'),
        ),
      ],
    );
  }

  String _waitingMessage(String? stage) => switch (stage) {
        'logging_in' => 'Đang đăng nhập trên máy chạy agent…',
        'tunnel_pending' => 'Đang mở đường kết nối ra ngoài…',
        _ => 'Đang chuẩn bị mã QR…',
      };

  /// QR về dạng data URL `data:image/png;base64,...`.
  Uint8List _decodeQr(String dataUrl) {
    final payload =
        dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return base64Decode(payload);
  }
}
```

Thêm `import 'dart:typed_data';` cho `Uint8List`. Token đã đối chiếu với code thật: `OmniColors` có `success`, `warning`, `destructive` (KHÔNG có `danger`); `OmniType` có `body`, `bodyStrong`, `micro`; `OmniRadius` nằm chung file với `OmniSpacing` nên barrel `tokens.dart` đã mang vào.

- [ ] **Step 4: Thêm route vào `channels_module.dart`**

```dart
  static const pair = 'channels.pair';
```

```dart
        ModuleRoute(
          path: '/channels/pair/:channelId',
          name: pair,
          rootNavigator: true,
          access: const AccessRequirement.any([ChannelPermissions.write]),
          builder: (_, state) => PairPage(
            channel: Channel.parse(state.pathParameters['channelId']),
          ),
        ),
```

Thêm import `'../../core/domain/channel.dart'` và `'presentation/pair_page.dart'`.

- [ ] **Step 5: Mở trang ghép nối từ `channels_page.dart`**

Trong `_pickChannel`, nhánh `ConnectMethod.pair`:

```dart
      case ConnectMethod.pair:
        await context.pushNamed(
          ChannelsModule.pair,
          pathParameters: {'channelId': channel.slug},
        );
        ref.invalidate(channelsProvider);
```

Và `onReconnect` của thẻ kênh cá nhân gọi đúng lời gọi trên với `connection.channel`. Thêm import `package:go_router/go_router.dart` và `'../channels_module.dart'`.

- [ ] **Step 6: Chạy toàn bộ test + phân tích**

Run: `flutter test && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/modules/channels
git commit -m "feat(channels): trang ghép nối QR, poll dừng khi app xuống nền"
```

---

### Task 6: Lưu ảnh QR vào thư viện

**Files:**
- Modify: `pubspec.yaml` (thêm `gal`)
- Modify: `android/app/src/main/AndroidManifest.xml` (quyền cho Android ≤ 9)
- Create: `lib/modules/channels/presentation/widgets/qr_saver.dart`
- Modify: `lib/modules/channels/presentation/pair_page.dart` (nối nút Lưu ảnh)

**Interfaces:**
- Consumes: `state.snapshot.qr` (Task 2).
- Produces: `Future<void> saveQrToGallery(String dataUrl)` — ném `Exception` với thông báo tiếng Việt khi hỏng.

- [ ] **Step 1: Thêm gói**

Trong `pubspec.yaml`, dưới `url_launcher`:

```yaml
  # Lưu ảnh QR vào thư viện để quét lại bằng Zalo trên chính máy đó.
  gal: ^2.3.0
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Khai quyền cho Android 9 trở xuống**

Trong `android/app/src/main/AndroidManifest.xml`, ngay dưới dòng `INTERNET`:

```xml
    <!-- Lưu ảnh QR vào thư viện, để quét lại bằng Zalo trên chính máy này.
         Từ Android 10 (API 29) MediaStore không cần quyền; minSdk của app là 24
         nên vẫn phải khai cho những máy cũ hơn. -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
```

- [ ] **Step 3: Viết `qr_saver.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Lưu ảnh QR (data URL base64) vào thư viện ảnh của máy.
///
/// Cần thế vì điện thoại không tự quét được màn hình của chính nó: người dùng
/// lưu ảnh, mở Zalo, chọn quét mã, rồi chọn ảnh này từ thư viện.
///
/// `Gal.putImageBytes` ghi thẳng từ bộ nhớ nên không cần file tạm, tức không
/// cần thêm `path_provider`.
Future<void> saveQrToGallery(String dataUrl) async {
  final Uint8List bytes;
  try {
    final payload = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    bytes = base64Decode(payload);
  } catch (_) {
    throw Exception('Ảnh QR hỏng, thử lấy mã mới.');
  }

  try {
    await Gal.putImageBytes(bytes, name: 'omnicrm-qr');
  } on GalException catch (error) {
    throw Exception(switch (error.type) {
      GalExceptionType.accessDenied =>
        'Chưa cho phép lưu ảnh. Mở Cài đặt → Quyền để bật.',
      _ => 'Không lưu được ảnh QR.',
    });
  }
}
```

Nếu `GalExceptionType` không có nhánh `accessDenied` ở phiên bản đang cài, chạy `grep -rn "enum GalExceptionType" -A 10 ~/AppData/Local/Pub/Cache/hosted/pub.dev/gal-*/lib/` để lấy tên thật rồi khớp theo.

- [ ] **Step 4: Nối vào `pair_page.dart`**

Thêm import `'widgets/qr_saver.dart'` và thay `onPressed` của nút "Lưu ảnh QR":

```dart
            FilledButton.icon(
              onPressed: () => _saveQr(state.snapshot.qr!),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Lưu ảnh QR'),
            ),
```

Thêm hàm vào `_PairPageState`:

```dart
  Future<void> _saveQr(String dataUrl) async {
    try {
      await saveQrToGallery(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu vào thư viện. Quét ngay — mã đổi sau khoảng 100 giây.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
```

- [ ] **Step 5: Chạy toàn bộ test + phân tích**

Run: `flutter test && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 6: Dựng bản release để chắc chắn không vỡ lúc đóng gói**

Run: `flutter build apk --release`
Expected: `√ Built build\app\outputs\flutter-apk\app-release.apk`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/modules/channels
git commit -m "feat(channels): lưu ảnh QR để quét bằng Zalo trên chính máy đó"
```

---

## Kiểm thử tay sau khi xong

Chạy trên máy thật, không phải máy ảo — ghép nối cần cả Zalo lẫn thư viện ảnh.

1. Vào Thêm → Quản trị → **Kết nối kênh**. Danh sách hiện đúng hai nhóm.
2. Tắt hết máy chạy agent, bấm ghép nối Zalo cá nhân. Trong vòng 40 giây phải hiện cảnh báo agent chưa chạy — không quay spinner vô hạn.
3. Bật agent trên PC, ghép nối lại. QR hiện ra. Bấm **Lưu ảnh QR**, mở Zalo, quét từ thư viện. Màn hình chuyển `scanned` rồi `connected`, tự thoát, danh sách hiện kênh mới.
4. Lặp lại bước 3 nhưng sau khi QR hiện thì bấm Home, đợi 30 giây rồi quay lại app. Màn hình phải cập nhật ngay, không đứng ở trạng thái cũ.
5. Nối một Facebook Page qua OAuth. Trình duyệt mở, đăng nhập xong quay lại app — kênh mới tự xuất hiện trong vòng vài giây, không cần kéo làm mới.
6. Đăng nhập bằng tài khoản chỉ có `channels.read.own`: vẫn vào được màn hình, chỉ thấy tài khoản của mình. Đăng nhập bằng tài khoản không có quyền kênh: không thấy mục trong "Thêm".
