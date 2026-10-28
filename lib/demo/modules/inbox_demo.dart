import '../demo_backend.dart';
import '../demo_seed.dart';

/// Dữ liệu mẫu: hộp thư, kênh kết nối, thông báo.
///
/// Mỗi lần gọi [registerInboxDemo] dựng một kho MỚI trong RAM: mọi thao tác
/// (gửi tin, đánh dấu đã đọc, giao người, gắn nhãn…) chỉ sống trong phiên đó,
/// không ghi đi đâu. Tên khách, địa chỉ, mã đơn đều BỊA.
void registerInboxDemo(DemoRoutes r, [DemoLinks? links]) =>
    (_InboxDemo()..links = links).register(r);

// ── Người phụ trách (chỉ số trong `demoPeople`) ─────────────────────────────

const _me = 0;
const _ma = 1; // Trần Minh Anh
const _qb = 2; // Lê Quốc Bảo
const _th = 3; // Phạm Thu Hà

// ── Kênh đã kết nối ─────────────────────────────────────────────────────────

const _connFb = '01900000-0000-7000-8000-0000000c4001';
const _connOa = '01900000-0000-7000-8000-0000000c4002';
const _connZaloMa = '01900000-0000-7000-8000-0000000c4003';
const _connZaloQb = '01900000-0000-7000-8000-0000000c4004';

const _connections = <Map<String, Object?>>[
  {
    'id': _connFb,
    'channel_id': 'facebook',
    'name': 'Viomni Nội Thất & Gia Dụng',
    'status': 'connected',
    'owner_name': null,
    'display_label': 'Facebook Page · Viomni Nội Thất & Gia Dụng',
  },
  {
    'id': _connOa,
    'channel_id': 'zalo',
    'name': 'Viomni Store',
    'status': 'connected',
    'owner_name': null,
    'display_label': 'Zalo OA · Viomni Store',
  },
  {
    'id': _connZaloMa,
    'channel_id': 'zalo_personal',
    'name': 'Trần Minh Anh',
    'status': 'connected',
    'owner_name': 'Trần Minh Anh',
    'display_label': 'Zalo cá nhân · Minh Anh',
  },
  {
    'id': _connZaloQb,
    'channel_id': 'zalo_personal',
    'name': 'Lê Quốc Bảo',
    // Một kênh hỏng phiên để màn Kênh có đủ trạng thái.
    'status': 'error',
    'owner_name': 'Lê Quốc Bảo',
    'display_label': 'Zalo cá nhân · Quốc Bảo',
  },
];

/// Bản demo chỉ gửi tin chữ: ẩn nút ảnh/tệp/ghi âm (tải lên cần máy chủ thật).
const _textOnly = <String, Object>{
  'can_send': true,
  'text': 'native',
  'image': 'none',
  'file': 'none',
  'audio': 'none',
  'video': 'none',
};

const _knownLabels = <String>[
  'Khách mới',
  'Đặt hàng',
  'Bảo hành',
  'Đổi trả',
  'Khách quen',
  'Đại lý',
];

const _quickReplies = <Map<String, String>>[
  {
    'id': 'qr-chao',
    'title': 'Chào khách',
    'body': 'Dạ Viomni xin chào anh/chị ạ! Em có thể hỗ trợ gì cho mình ạ?',
  },
  {
    'id': 'qr-sdt',
    'title': 'Xin số điện thoại',
    'body':
        'Anh/chị cho em xin số điện thoại để bộ phận tư vấn gọi lại hỗ trợ '
        'chi tiết nhé ạ.',
  },
  {
    'id': 'qr-giao',
    'title': 'Giao lắp',
    'body':
        'Dạ Viomni miễn phí giao và lắp đặt trong nội thành TP.HCM, thời gian '
        '2–3 ngày sau khi đặt hàng ạ.',
  },
  {
    'id': 'qr-bh',
    'title': 'Bảo hành',
    'body':
        'Dạ sản phẩm được bảo hành chính hãng 12–24 tháng tuỳ loại, đổi mới '
        'trong 7 ngày nếu lỗi do nhà sản xuất ạ.',
  },
  {
    'id': 'qr-camon',
    'title': 'Cảm ơn',
    'body':
        'Dạ cảm ơn anh/chị đã tin tưởng Viomni. Chúc anh/chị một ngày vui '
        'vẻ ạ!',
  },
];

// ── Kịch bản hội thoại ──────────────────────────────────────────────────────

/// Một dòng chat mẫu. [ago] = số phút trước lúc mở app.
class _L {
  const _L(
    this.out,
    this.ago,
    this.text, {
    this.by = _me,
    this.sender,
    this.failed,
    this.pinned = false,
    this.reacts = const {},
  });

  final bool out;
  final int ago;
  final String text;

  /// Người gửi phía cửa hàng (tin đi).
  final int by;

  /// Thành viên nhóm gửi tin (chỉ hội thoại nhóm).
  final String? sender;

  /// Lý do gửi lỗi — tin đi ở trạng thái `failed`.
  final String? failed;
  final bool pinned;

  /// Cảm xúc nội bộ: chỉ số người → emoji.
  final Map<int, String> reacts;
}

class _S {
  const _S({
    required this.n,
    required this.conn,
    required this.lines,
    this.name,
    this.unread = 0,
    this.assignee,
    this.tags = const [],
    this.urgent = false,
    this.status = 'open',
    this.pinned = false,
    this.muted = false,
    this.blocked = false,
    this.groupName,
    this.members = const [],
    this.autoReply,
  });

  final int n;
  final String conn;
  final String? name;
  final int unread;
  final int? assignee;
  final List<String> tags;
  final bool urgent;
  final String status;
  final bool pinned;
  final bool muted;
  final bool blocked;
  final String? groupName;
  final List<String> members;
  final List<_L> lines;

  /// Khách nhắn lại vài giây sau tin đầu tiên nhân viên gửi trong phiên.
  final String? autoReply;
}

const _seeds = <_S>[
  _S(
    n: 1,
    conn: _connFb,
    name: 'Nguyễn Thị Hồng Nhung',
    unread: 2,
    assignee: _qb,
    tags: ['Khách mới'],
    autoReply: 'Dạ vậy mình cọc 2 triệu trước nhé shop, gửi mình số tài khoản.',
    lines: [
      _L(
        false,
        95,
        'Chào shop, mình xem bài đăng sofa góc chữ L màu xám ạ. '
        'Mẫu này còn hàng không shop?',
      ),
      _L(
        true,
        92,
        'Dạ chào chị Nhung ạ! Mẫu sofa góc L vải nỉ xám hiện còn 2 '
        'bộ và hàng mới về cuối tuần này chị nhé.',
        by: _qb,
      ),
      _L(
        true,
        91,
        'Kích thước 2m8 x 1m6, đệm mút D40 không xẹp, khung gỗ dầu '
        'ạ.',
        by: _qb,
      ),
      _L(false, 80, 'Giá bộ này bao nhiêu vậy shop?'),
      _L(
        true,
        78,
        'Dạ giá niêm yết 15.900.000đ, tháng này shop giảm 10% còn '
        '14.310.000đ chị ạ. Tặng kèm 4 gối tựa.',
        by: _qb,
        pinned: true,
      ),
      _L(
        false,
        70,
        'Nhà mình ở Linh Đông, Thủ Đức. Có giao lắp tận nơi '
        'không?',
      ),
      _L(
        true,
        66,
        'Dạ có chị. Nội thành TP.HCM và Thủ Đức shop miễn phí giao '
        '+ lắp, thường trong 2–3 ngày sau khi đặt ạ.',
        by: _qb,
      ),
      _L(false, 40, 'Có màu kem không shop? Phòng khách nhà mình tông sáng.'),
      _L(
        true,
        37,
        'Dạ màu kem be có ạ, nhưng hàng đặt thêm khoảng 10 ngày. Em '
        'gửi chị bảng màu vải để chị chọn nhé.',
        by: _qb,
      ),
      _L(false, 6, 'Ok shop, cho mình hỏi có cho đặt cọc trước không?'),
      _L(false, 4, 'Mình muốn giữ giá khuyến mãi tháng này.'),
    ],
  ),
  _S(
    n: 2,
    conn: _connOa,
    name: 'Trần Văn Hùng',
    assignee: _me,
    tags: ['Bảo hành'],
    autoReply: 'Ok em, tủ chạy ổn rồi. Cảm ơn em nhé.',
    lines: [
      _L(
        false,
        600,
        'Chào Viomni, tôi mua tủ lạnh Inverter 380 lít bên mình '
        'hồi tháng 3.',
      ),
      _L(
        false,
        599,
        'Mấy hôm nay ngăn mát không lạnh lắm, ngăn đá vẫn bình '
        'thường.',
      ),
      _L(
        true,
        590,
        'Dạ em chào anh Hùng ạ. Anh cho em xin mã hoá đơn để em '
        'kiểm tra bảo hành nhé.',
      ),
      _L(false, 580, 'Mã hoá đơn HD-24031 em nhé, đứng tên Trần Văn Hùng.'),
      _L(
        true,
        575,
        'Dạ em tìm thấy rồi ạ. Tủ còn bảo hành chính hãng 24 '
        'tháng, máy nén 10 năm anh nhé.',
      ),
      _L(
        true,
        574,
        'Anh kiểm tra giúp em: núm chỉnh nhiệt ngăn mát đang để mức '
        'mấy, và cửa tủ có đóng kín không ạ?',
      ),
      _L(false, 540, 'Để mức 3. Cửa thì đóng kín.'),
      _L(false, 539, 'Tủ hơi sát tường, chắc tầm 5 cm.'),
      _L(
        true,
        530,
        'Dạ anh thử kéo tủ cách tường khoảng 10 cm và chỉnh lên mức '
        '4, theo dõi giúp em 1 ngày nha anh. Nếu vẫn chưa lạnh, em đặt lịch '
        'kỹ thuật qua kiểm tra miễn phí.',
      ),
      _L(false, 300, 'Đã kéo ra rồi, hôm nay thấy có lạnh hơn.'),
      _L(
        true,
        290,
        'Dạ vậy tốt quá anh ạ. Tối nay anh để ý thêm, có gì anh '
        'nhắn em ngay nhé.',
      ),
      _L(false, 130, 'Ok cảm ơn em.'),
      _L(
        true,
        125,
        'Dạ không có gì ạ. Chúc anh và gia đình buổi tối vui vẻ!',
        reacts: {_ma: '👍'},
      ),
    ],
  ),
  _S(
    n: 3,
    conn: _connZaloMa,
    name: 'Lê Thu Trang',
    unread: 1,
    assignee: _ma,
    tags: ['Đặt hàng'],
    urgent: true,
    autoReply: 'Dạ em cảm ơn chị nhiều ạ!',
    lines: [
      _L(
        false,
        240,
        'Chị Minh Anh ơi, em muốn lấy máy lọc không khí loại phòng '
        '40m² hôm trước chị tư vấn.',
      ),
      _L(
        true,
        235,
        'Dạ Trang ơi, mẫu đó còn hàng nha em. Giá 4.290.000đ, bảo '
        'hành 24 tháng, tặng thêm 1 màng lọc thay thế.',
        by: _ma,
      ),
      _L(false, 230, 'Ok chị, em chuyển khoản luôn được không?'),
      _L(
        true,
        228,
        'Được em, hoặc em thanh toán khi nhận hàng cũng được. Em '
        'gửi chị địa chỉ giao nhé.',
        by: _ma,
      ),
      _L(
        false,
        220,
        'Dạ địa chỉ: 25 đường số 7, phường An Khánh, Thủ Đức. Em ở '
        'nhà buổi chiều.',
      ),
      _L(
        true,
        215,
        'Chị ghi nhận rồi. Dự kiến chiều mai giao, trước khi đến '
        'bạn giao hàng gọi em nhé.',
        by: _ma,
      ),
      _L(
        false,
        30,
        'Chị ơi mai em có việc đột xuất, chuyển sang sáng thứ Bảy '
        'được không chị?',
      ),
      _L(true, 25, 'Được em, để chị báo kho đổi lịch.', by: _ma),
      _L(
        false,
        3,
        'Dạ cảm ơn chị, nhờ chị nhắc bên giao gọi trước 30 phút '
        'giúp em nha.',
      ),
    ],
  ),
  _S(
    n: 4,
    conn: _connFb,
    name: 'Phạm Quang Huy',
    unread: 3,
    autoReply: 'Vậy mình ghé showroom cuối tuần xem trực tiếp nhé.',
    lines: [
      _L(false, 52, 'Chào shop'),
      _L(false, 50, 'Bàn ăn gỗ sồi 6 ghế giá sao shop?'),
      _L(
        true,
        48,
        'Dạ chào anh ạ. Bộ bàn ăn gỗ sồi 1m6 kèm 6 ghế bọc nệm giá '
        '12.500.000đ anh nhé.',
        by: _th,
      ),
      _L(false, 45, 'Mặt bàn có loại đá không shop?'),
      _L(
        true,
        44,
        'Dạ có bản mặt đá ceramic vân trắng, giá 14.200.000đ. Mặt đá '
        'chịu nhiệt, chống trầy, dễ lau chùi ạ.',
        by: _th,
      ),
      _L(false, 20, 'Bên mình có hỗ trợ trả góp không?'),
      _L(false, 19, 'Trả góp 0% qua thẻ tín dụng được không?'),
      _L(false, 18, 'Mình tính lấy luôn tủ giày nữa.'),
    ],
  ),
  _S(
    n: 5,
    conn: _connOa,
    name: 'Võ Ngọc Ánh',
    unread: 1,
    assignee: _th,
    tags: ['Bảo hành'],
    urgent: true,
    autoReply: 'Ok em, mai chị ở nhà cả ngày.',
    lines: [
      _L(
        false,
        4400,
        'Máy giặt cửa trước nhà mình báo lỗi E21, không xả nước '
        'được.',
      ),
      _L(
        true,
        4390,
        'Dạ chào chị Ánh, lỗi E21 thường do lọc xả bị nghẹt ạ. '
        'Chị tắt máy, rút điện rồi mở nắp lọc ở góc dưới mặt trước máy '
        'giúp em nhé.',
        by: _th,
      ),
      _L(
        true,
        4389,
        'Chị nhớ lót khăn vì nước sẽ chảy ra khá nhiều ạ.',
        by: _th,
      ),
      _L(false, 4360, 'Mình mở ra rồi, có mấy đồng xu với sợi vải.'),
      _L(false, 4359, 'Vệ sinh xong chạy lại vẫn báo E21.'),
      _L(
        true,
        4350,
        'Dạ vậy có thể bơm xả bị hỏng, em đặt lịch kỹ thuật sang '
        'kiểm tra cho chị. Máy còn bảo hành nên chị không mất phí ạ.',
        by: _th,
      ),
      _L(true, 4349, 'Chị cho em xin khung giờ tiện nhất nhé.', by: _th),
      _L(false, 4330, 'Sáng mai 9–11h được không em?'),
      _L(
        true,
        4325,
        'Dạ được chị. Anh Đức Long bên kỹ thuật sẽ qua, trước khi '
        'đến anh ấy gọi chị.',
        by: _th,
      ),
      _L(
        false,
        2900,
        'Kỹ thuật báo phải đặt bơm xả mới, mấy ngày mới có vậy '
        'em?',
      ),
      _L(
        true,
        2890,
        'Dạ linh kiện về trong 2–3 ngày làm việc ạ. Có hàng em báo '
        'chị ngay và hẹn lịch thay luôn.',
        by: _th,
      ),
      _L(false, 12, 'Đã 3 ngày rồi em ơi, nhà mình đồ giặt dồn nhiều quá.'),
    ],
  ),
  _S(
    n: 6,
    conn: _connZaloQb,
    name: 'Đặng Minh Khoa',
    assignee: _qb,
    tags: ['Khách quen'],
    lines: [
      _L(
        false,
        2000,
        'Bảo ơi, anh định lấy giường 1m8 gỗ óc chó với nệm cao su '
        'luôn.',
      ),
      _L(
        true,
        1995,
        'Dạ anh Khoa! Combo giường óc chó 1m8x2m + nệm cao su 20 '
        'cm bên em đang có giá 28.900.000đ, rẻ hơn mua lẻ gần 3 triệu anh '
        'ạ.',
        by: _qb,
      ),
      _L(false, 1990, 'Có tab đầu giường đi kèm không?'),
      _L(
        true,
        1985,
        'Dạ combo chưa gồm tab, anh lấy thêm cặp tab cùng bộ em để '
        'giá 3.200.000đ cho anh.',
        by: _qb,
      ),
      _L(false, 1980, 'Ok lấy luôn cặp tab. Thứ Bảy giao được không?'),
      _L(
        true,
        1975,
        'Dạ được anh, em lên đơn giao lắp sáng thứ Bảy nhé. Anh '
        'cọc trước 30% giúp em.',
        by: _qb,
      ),
      _L(false, 1970, 'Anh chuyển rồi nhé.'),
      _L(
        true,
        1960,
        'Em nhận được rồi ạ, cảm ơn anh. Em gửi phiếu xác nhận đơn '
        'qua email cho anh.',
        by: _qb,
      ),
      _L(
        false,
        300,
        'Hàng giao lắp xong rồi, giường chắc chắn lắm. Cảm ơn '
        'Bảo.',
      ),
      _L(
        true,
        290,
        'Dạ em cảm ơn anh đã tin tưởng ạ. Có gì cần hỗ trợ anh cứ '
        'nhắn em nhé!',
        by: _qb,
        reacts: {_ma: '❤️', _me: '👍'},
      ),
    ],
  ),
  _S(
    n: 7,
    conn: _connFb,
    name: 'Bùi Thị Mai',
    assignee: _th,
    status: 'closed',
    lines: [
      _L(false, 5000, 'Nồi chiên không dầu 6 lít còn khuyến mãi không shop?'),
      _L(
        true,
        4990,
        'Dạ còn chị ạ, giá 1.890.000đ, tặng kèm khay nướng và giấy '
        'lót. Bảo hành 12 tháng.',
        by: _th,
      ),
      _L(false, 4980, 'Có màu đen không?'),
      _L(true, 4975, 'Dạ có màu đen và trắng chị nhé.', by: _th),
      _L(false, 4960, 'Cho chị 1 cái màu đen, giao về Bình Thạnh.'),
      _L(
        true,
        4955,
        'Dạ em lên đơn rồi ạ. Nội thành miễn phí giao, dự kiến '
        'giao trong ngày mai.',
        by: _th,
      ),
      _L(false, 3500, 'Nhận được rồi nha shop, dùng thử chiên gà ngon lắm.'),
      _L(true, 3490, 'Dạ cảm ơn chị đã ủng hộ Viomni ạ!', by: _th),
    ],
  ),
  _S(
    n: 8,
    conn: _connOa,
    name: 'Hoàng Gia Bảo',
    unread: 2,
    tags: ['Khách mới'],
    autoReply: 'Ok shop, sáng thứ Bảy nhé.',
    lines: [
      _L(
        false,
        78,
        'Chào shop, mình cần lắp điều hòa cho phòng ngủ khoảng '
        '18m².',
      ),
      _L(
        true,
        72,
        'Dạ chào anh ạ. Phòng 18m² dùng máy 1.5 HP là vừa. Bên em có '
        'mẫu Inverter tiết kiệm điện giá 9.490.000đ, đã gồm công lắp và 5m '
        'ống đồng.',
        by: _ma,
      ),
      _L(
        true,
        71,
        'Anh cho em hỏi phòng có nắng chiều không để em tư vấn chính '
        'xác hơn nhé.',
        by: _ma,
      ),
      _L(false, 65, 'Phòng hướng tây, chiều nắng gắt lắm.'),
      _L(false, 60, 'Nhà mình ở chung cư tầng 12, có lắp được không?'),
      _L(
        true,
        58,
        'Dạ được anh, kỹ thuật bên em có đồ bảo hộ làm việc trên '
        'cao. Em cần khảo sát vị trí đặt cục nóng trước ạ.',
        by: _ma,
      ),
      _L(false, 26, 'Khảo sát có mất phí không?'),
      _L(false, 25, 'Cuối tuần này qua được không shop?'),
    ],
  ),
  _S(
    n: 9,
    conn: _connZaloMa,
    groupName: 'Đại lý Viomni Miền Tây',
    members: [
      'Anh Lộc (Long Xuyên)',
      'Chị Diễm (Vĩnh Long)',
      'Chú Tư (Cần Thơ)',
    ],
    unread: 4,
    assignee: _ma,
    tags: ['Đại lý'],
    muted: true,
    lines: [
      _L(
        false,
        900,
        'Chào cả nhóm, tuần này có bảng giá sỉ mới chưa chị Minh '
        'Anh?',
        sender: 'Anh Lộc (Long Xuyên)',
      ),
      _L(
        true,
        880,
        'Dạ có rồi anh Lộc, bảng giá sỉ tháng 11 em gửi qua email '
        'từng đại lý trong sáng nay ạ.',
        by: _ma,
      ),
      _L(
        false,
        870,
        'Quạt điều hoà hơi nước còn hàng không em? Bên chị khách '
        'hỏi nhiều.',
        sender: 'Chị Diễm (Vĩnh Long)',
      ),
      _L(
        true,
        860,
        'Dạ còn khoảng 40 cái chị ơi, chị cần bao nhiêu em giữ hàng '
        'cho ạ.',
        by: _ma,
      ),
      _L(false, 850, 'Giữ cho chị 10 cái nhé.', sender: 'Chị Diễm (Vĩnh Long)'),
      _L(
        false,
        400,
        'Bếp từ đôi có giảm cho đại lý không con?',
        sender: 'Chú Tư (Cần Thơ)',
      ),
      _L(
        true,
        390,
        'Dạ đơn từ 5 bếp con chiết khấu thêm 3% chú Tư ạ.',
        by: _ma,
      ),
      _L(
        false,
        60,
        'Xe hàng đi Long Xuyên tuần này chạy ngày nào em?',
        sender: 'Anh Lộc (Long Xuyên)',
      ),
      _L(
        false,
        58,
        'Cho chú hỏi luôn chuyến Cần Thơ nhé.',
        sender: 'Chú Tư (Cần Thơ)',
      ),
      _L(
        false,
        40,
        'Chị chuyển cọc 10 quạt rồi nha em.',
        sender: 'Chị Diễm (Vĩnh Long)',
      ),
      _L(
        false,
        15,
        'Nhóm mình ai cần catalogue Tết thì báo nhé, mình in thêm '
        'luôn.',
        sender: 'Anh Lộc (Long Xuyên)',
      ),
    ],
  ),
  _S(
    n: 10,
    conn: _connFb,
    name: 'Ngô Thanh Tâm',
    assignee: _me,
    tags: ['Đặt hàng'],
    pinned: true,
    autoReply: 'Ok em, có tiến độ thì nhắn chị nhé.',
    lines: [
      _L(
        false,
        3000,
        'Shop có nhận làm tủ quần áo cửa lùa theo kích thước '
        'không?',
      ),
      _L(
        true,
        2990,
        'Dạ có ạ. Chị cho em xin kích thước dự kiến (rộng x cao x '
        'sâu) và chất liệu mong muốn nhé.',
      ),
      _L(
        false,
        2980,
        'Rộng 2m4, cao 2m6 sát trần, sâu 60. Gỗ MDF chống ẩm, màu '
        'vân sồi.',
      ),
      _L(
        true,
        2970,
        'Dạ với kích thước này, tủ 3 cánh lùa MDF lõi xanh chống '
        'ẩm phủ melamine vân sồi giá khoảng 16.800.000đ, đã gồm ray giảm '
        'chấn ạ.',
        pinned: true,
      ),
      _L(false, 2960, 'Có làm thêm ngăn kéo bên trong được không?'),
      _L(
        true,
        2950,
        'Dạ được, mỗi ngăn kéo thêm 650.000đ. Em đề xuất 3 ngăn kéo '
        'ở khoang giữa ạ.',
      ),
      _L(false, 1500, 'Ok, khi nào bên mình qua đo thực tế?'),
      _L(
        true,
        1490,
        'Dạ thứ Năm này 14h kỹ thuật bên em qua đo được không '
        'chị?',
      ),
      _L(false, 1485, 'Được nhé.'),
      _L(
        true,
        200,
        'Dạ em gửi lại bản vẽ 3D đã chỉnh theo số đo thực tế qua '
        'email rồi ạ. Chị xem giúp em nhé.',
      ),
      _L(false, 150, 'Chị xem rồi, ưng lắm. Chốt luôn em nhé.'),
      _L(
        true,
        140,
        'Dạ em cảm ơn chị! Thời gian sản xuất 12 ngày, em sẽ cập '
        'nhật tiến độ cho chị.',
        reacts: {_qb: '🎉'},
      ),
    ],
  ),
  _S(
    n: 11,
    conn: _connOa,
    name: 'Trịnh Hải Yến',
    assignee: _th,
    tags: ['Đổi trả'],
    status: 'pending',
    autoReply: 'Được em, 15h chị có nhà.',
    lines: [
      _L(
        false,
        1800,
        'Bình nóng lạnh 30 lít mình mua tuần trước bị rò nước ở '
        'van.',
      ),
      _L(
        true,
        1790,
        'Dạ em xin lỗi chị Yến vì sự bất tiện này ạ. Chị cho em xin '
        'mã đơn để em kiểm tra nhé.',
        by: _th,
      ),
      _L(false, 1780, 'Mã đơn DH-10482.'),
      _L(
        true,
        1770,
        'Dạ đơn còn trong 7 ngày đổi mới. Em sắp xếp đổi bình mới '
        'cho chị, kỹ thuật tháo lắp miễn phí ạ.',
        by: _th,
      ),
      _L(false, 1760, 'Vậy khi nào đổi được em?'),
      _L(
        true,
        1750,
        'Dạ em đang chờ kho xác nhận hàng mới, chậm nhất ngày mai '
        'em báo lịch cho chị.',
        by: _th,
      ),
      _L(false, 1740, 'Ok em.'),
      _L(
        true,
        600,
        'Dạ chị Yến ơi, kho đã có hàng. Chiều nay 15h kỹ thuật qua '
        'đổi cho chị được không ạ?',
        by: _th,
      ),
    ],
  ),
  _S(
    n: 12,
    conn: _connFb,
    name: 'Dịch Vụ Quảng Cáo 247',
    tags: ['Spam'],
    blocked: true,
    lines: [
      _L(false, 7000, 'Dịch vụ tăng like, tăng theo dõi giá rẻ, nhắn ngay!'),
      _L(false, 6990, 'Ưu đãi chạy quảng cáo trọn gói chỉ từ 99k/ngày.'),
      _L(false, 6980, 'Shop ơi trả lời em với ạ!!!'),
    ],
  ),
  _S(
    n: 13,
    conn: _connFb,
    name: 'Đỗ Khánh Linh',
    assignee: _qb,
    autoReply: 'Ok shop, để mình qua xem trực tiếp rồi chốt nhé.',
    lines: [
      _L(false, 4400, 'Kệ tivi gỗ 1m8 màu óc chó còn không shop?'),
      _L(
        true,
        4390,
        'Dạ còn ạ, giá 3.650.000đ, chân sắt sơn tĩnh điện, có 2 hộc '
        'kéo.',
        by: _qb,
      ),
      _L(false, 4380, 'Để tivi 55 inch vừa không?'),
      _L(
        true,
        4370,
        'Dạ vừa ạ, kệ chịu tải 80 kg, tivi 55 inch đặt rất cân '
        'đối.',
        by: _qb,
      ),
      _L(false, 4360, 'Shop gửi mình kích thước chi tiết nhé.'),
      _L(true, 4350, 'Dạ kích thước 180 x 40 x 50 cm ạ.', by: _qb),
      _L(false, 4340, 'Để mình hỏi chồng đã nha.'),
      _L(
        true,
        2900,
        'Dạ chị Linh ơi, mẫu kệ này cuối tuần có ưu đãi giảm thêm '
        '300.000đ, chị cân nhắc nhé!',
        by: _qb,
        failed:
            'Messenger chỉ cho trả lời trong 24 giờ kể từ tin cuối của '
            'khách — tin chưa đến khách.',
      ),
    ],
  ),
];

// ── Thông báo ───────────────────────────────────────────────────────────────

class _N {
  const _N(
    this.type,
    this.ago,
    this.title,
    this.content, {
    this.read = false,
    this.conv,
  });

  final String type;
  final int ago;
  final String title;
  final String content;
  final bool read;

  /// Số thứ tự hội thoại (`_S.n`) khi là thông báo tin nhắn.
  final int? conv;
}

const _notifSeeds = <_N>[
  _N(
    'INBOX_MESSAGE',
    3,
    'Tin nhắn mới từ Lê Thu Trang',
    'Dạ cảm ơn chị, nhờ chị nhắc bên giao gọi trước 30 phút giúp em nha.',
    conv: 3,
  ),
  _N(
    'INBOX_MESSAGE',
    4,
    'Tin nhắn mới từ Nguyễn Thị Hồng Nhung',
    'Mình muốn giữ giá khuyến mãi tháng này.',
    conv: 1,
  ),
  _N(
    'INBOX_MESSAGE',
    12,
    'Tin nhắn mới từ Võ Ngọc Ánh',
    'Đã 3 ngày rồi em ơi, nhà mình đồ giặt dồn nhiều quá.',
    conv: 5,
  ),
  _N(
    'TASK_REMINDER',
    20,
    'Nhắc việc',
    'Gọi xác nhận lịch đổi bình nóng lạnh cho chị Trịnh Hải Yến.',
  ),
  _N(
    'TASK_ASSIGNED',
    35,
    'Bạn được giao việc mới',
    'Trần Minh Anh giao: Gọi lại khách Hoàng Gia Bảo về khảo sát lắp điều '
        'hoà.',
  ),
  _N(
    'TASK_DUE_SOON',
    60,
    'Việc sắp đến hạn',
    'Gửi hợp đồng tủ quần áo đặt riêng cho chị Ngô Thanh Tâm — hạn 17:00 '
        'hôm nay.',
  ),
  _N(
    'TASK_COMMENTED',
    180,
    'Phạm Thu Hà bình luận',
    'Linh kiện bơm xả đã về kho, hẹn thay cho khách chiều mai.',
    read: true,
  ),
  _N(
    'TASK_MENTIONED',
    300,
    'Lê Quốc Bảo nhắc đến bạn',
    '@Người dùng Demo duyệt giúp chiết khấu combo giường + nệm.',
    read: true,
  ),
  _N(
    'INBOX_MESSAGE',
    130,
    'Tin nhắn mới từ Trần Văn Hùng',
    'Ok cảm ơn em.',
    read: true,
    conv: 2,
  ),
  _N(
    'TASK_COMPLETED',
    1440,
    'Nguyễn Đức Long hoàn thành việc',
    'Lắp đặt tủ lạnh cho khách tại Quận 7.',
    read: true,
  ),
  _N(
    'TASK_OVERDUE',
    2880,
    'Việc quá hạn',
    'Kiểm kê hàng phòng trưng bày tháng 10.',
    read: true,
  ),
];

// ── Tiện ích ────────────────────────────────────────────────────────────────

String _pad(int v, int width) => v.toString().padLeft(width, '0');

String _convId(int n) => '01900000-0000-7000-8000-0000000c${_pad(n, 4)}';

String _msgId(int n, int k) =>
    '01900000-0000-7000-8c${_pad(n, 2)}-${_pad(k, 12)}';

String _iso(DateTime t) => t.toUtc().toIso8601String();

DateTime _minutesAgo(int m) => DateTime.now().subtract(Duration(minutes: m));

const _folds = <String>[
  'aàáạảãâầấậẩẫăằắặẳẵ',
  'eèéẹẻẽêềếệểễ',
  'iìíịỉĩ',
  'oòóọỏõôồốộổỗơờớợởỡ',
  'uùúụủũưừứựửữ',
  'yỳýỵỷỹ',
  'dđ',
];

/// Bỏ dấu tiếng Việt để tìm "nhung" ra "Nhung", "nồi" ra "noi".
String _fold(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    var mapped = ch;
    for (final group in _folds) {
      if (group.contains(ch)) {
        mapped = group[0];
        break;
      }
    }
    out.write(mapped);
  }
  return out.toString();
}

bool _truthy(String? v) => v == '1' || v == 'true';

/// Một lượt khách nhắn lại đang chờ tới giờ.
class _PendingReply {
  _PendingReply(this.conversationId, this.due, this.text);

  final String conversationId;
  final DateTime due;
  final String text;
}

/// Kho trong RAM của phiên demo.
class _InboxDemo {
  _InboxDemo() {
    _seed();
  }

  DemoLinks? links;

  /// id → tài liệu hội thoại (đúng khoá API trả).
  final _convs = <String, Map<String, dynamic>>{};

  /// id hội thoại → tin, cũ → mới.
  final _threads = <String, List<Map<String, dynamic>>>{};

  final _connectionsLive = <Map<String, dynamic>>[
    for (final c in _connections) Map<String, dynamic>.from(c),
  ];

  final _notifications = <Map<String, dynamic>>[];
  final _labels = <String>{..._knownLabels};
  final _autoReplyText = <String, String>{};
  final _autoReplied = <String>{};
  final _pending = <_PendingReply>[];

  /// Nhật ký thay đổi cho `GET /inbox/changes`: (số thứ tự, id hội thoại).
  final _events = <(int, String)>[];
  int _rev = 1;

  // ── Dựng dữ liệu ──────────────────────────────────────────────────────────

  void _seed() {
    for (final s in _seeds) {
      final id = _convId(s.n);
      final conn = _connections.firstWhere((c) => c['id'] == s.conn);
      final assignee = s.assignee == null ? null : demoPeople[s.assignee!];
      final messages = <Map<String, dynamic>>[];
      for (var k = 0; k < s.lines.length; k++) {
        final l = s.lines[k];
        final at = _iso(_minutesAgo(l.ago));
        final agent = l.out ? demoPeople[l.by] : null;
        messages.add({
          'id': _msgId(s.n, k + 1),
          'conversation_id': id,
          'client_message_id': null,
          'direction': l.out ? 'out' : 'in',
          'from': l.out ? 'agent' : 'customer',
          'text': l.text,
          'sent_at': at,
          'created_at': at,
          'status': l.failed != null ? 'failed' : (l.out ? 'read' : 'received'),
          'error': l.failed,
          'error_code': l.failed != null ? 'outside_messaging_window' : null,
          'recalled': false,
          'pinned': l.pinned,
          'reaction': null,
          'agent_name': agent?.name,
          'sender_name': l.out ? agent?.name : (l.sender ?? s.name),
          'sender_avatar': null,
          'reply_to_message_id': null,
          'reply_to_text': null,
          'reply_to_author_name': null,
          'attachments': <Object>[],
          'team_reactions': [
            for (final e in l.reacts.entries)
              {
                'user_id': demoPeople[e.key].id,
                'user_name': demoPeople[e.key].name,
                'emoji': e.value,
                'at': at,
              },
          ],
        });
      }
      _threads[id] = messages;
      final last = messages.last;
      final isGroup = s.groupName != null;
      _convs[id] = {
        'id': id,
        'channel': conn['channel_id'],
        'status': s.status,
        'customer_id': null,
        'customer_name': s.name,
        'customer_avatar': null,
        'last_message': last['text'],
        'last_message_at': last['sent_at'],
        'unread_count': s.unread,
        'priority': s.urgent ? 'urgent' : 'normal',
        'assignee': assignee?.id,
        'assignee_name': assignee?.name,
        'tags': [...s.tags],
        'connection_id': s.conn,
        'source_name': conn['display_label'],
        'is_group': isGroup,
        'group_name': s.groupName,
        'group_members': [
          for (var i = 0; i < s.members.length; i++)
            {'id': 'gm-${s.n}-$i', 'name': s.members[i], 'avatar': null},
        ],
        'is_pinned': s.pinned,
        'is_muted': s.muted,
        'blocked_at': s.blocked ? _iso(_minutesAgo(6900)) : null,
        'outbound_capabilities': _textOnly,
        'created_at': messages.first['sent_at'],
        'updated_at': last['sent_at'],
      };
      _labels.addAll(s.tags);
      if (s.autoReply != null) _autoReplyText[id] = s.autoReply!;
    }

    for (var i = 0; i < _notifSeeds.length; i++) {
      final n = _notifSeeds[i];
      final at = _minutesAgo(n.ago);
      _notifications.add({
        'id': '01900000-0000-7000-8000-0000000e${_pad(i + 1, 4)}',
        'notification_type': n.type,
        'title': n.title,
        'content': n.content,
        'created_at': _iso(at),
        'read_at': n.read ? _iso(at.add(const Duration(minutes: 2))) : null,
        // Thông báo việc không gắn id: việc mẫu nằm ở module khác, bấm vào
        // chỉ đánh dấu đã đọc thay vì mở một việc không có.
        'related_entity_type': n.conv != null ? 'conversation' : null,
        'related_entity_id': n.conv != null ? _convId(n.conv!) : null,
      });
    }
  }

  // ── Khách nhắn lại (không hẹn giờ: tới hạn thì hiện ở lượt đọc kế) ────────

  void _flush() {
    if (_pending.isEmpty) return;
    final now = DateTime.now();
    final due = _pending.where((p) => !p.due.isAfter(now)).toList();
    for (final p in due) {
      _pending.remove(p);
      final conv = _convs[p.conversationId];
      if (conv == null || conv['blocked_at'] != null) continue;
      final at = _iso(p.due);
      _threads[p.conversationId]!.add(
        _message(
          conversationId: p.conversationId,
          out: false,
          text: p.text,
          at: at,
          senderName: conv['customer_name'] as String?,
        ),
      );
      conv['last_message'] = p.text;
      conv['last_message_at'] = at;
      conv['updated_at'] = at;
      conv['unread_count'] = (conv['unread_count'] as int) + 1;
      if (conv['status'] == 'closed') conv['status'] = 'open';
      _events.add((++_rev, p.conversationId));
      _notifications.insert(0, {
        'id': demoNewId(),
        'notification_type': 'INBOX_MESSAGE',
        'title': 'Tin nhắn mới từ ${conv['customer_name']}',
        'content': p.text,
        'created_at': at,
        'read_at': null,
        'related_entity_type': 'conversation',
        'related_entity_id': p.conversationId,
      });
    }
  }

  Map<String, dynamic> _message({
    required String conversationId,
    required bool out,
    required String text,
    required String at,
    String? clientId,
    String? senderName,
    Map<String, dynamic>? replyTo,
  }) {
    return {
      'id': demoNewId(),
      'conversation_id': conversationId,
      'client_message_id': clientId,
      'direction': out ? 'out' : 'in',
      'from': out ? 'agent' : 'customer',
      'text': text,
      'sent_at': at,
      'created_at': at,
      'status': out ? 'sent' : 'received',
      'error': null,
      'error_code': null,
      'recalled': false,
      'pinned': false,
      'reaction': null,
      'agent_name': out ? demoMe.name : null,
      'sender_name': out ? demoMe.name : senderName,
      'sender_avatar': null,
      'reply_to_message_id': replyTo?['id'],
      'reply_to_text': replyTo?['text'],
      'reply_to_author_name': replyTo?['sender_name'],
      'attachments': <Object>[],
      'team_reactions': <Object>[],
    };
  }

  // ── Hội thoại ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _convJson(Map<String, dynamic> c) => {
    ...c,
    'tags': [...(c['tags'] as List)],
  };

  String _haystack(Map<String, dynamic> c) {
    final parts = <String>[
      '${c['customer_name'] ?? ''}',
      '${c['group_name'] ?? ''}',
      '${c['last_message'] ?? ''}',
      for (final m in _threads[c['id']] ?? const <Map<String, dynamic>>[])
        '${m['text']}',
    ];
    return _fold(parts.join(' '));
  }

  /// Bộ lọc "nền": kênh / tài khoản / nhãn / tìm kiếm / chặn — phần mà số
  /// đếm của các nút lọc nhanh cùng chia sẻ.
  bool _baseMatch(
    Map<String, dynamic> c,
    DemoRequest req, {
    bool ignoreChannel = false,
    bool ignoreLabel = false,
  }) {
    final blockedOnly = _truthy(req.q('blocked'));
    final isBlocked = c['blocked_at'] != null;
    if (blockedOnly != isBlocked) return false;
    final channel = req.q('channel');
    if (!ignoreChannel && channel != null && c['channel'] != channel) {
      return false;
    }
    final conn = req.q('connection_id');
    if (!ignoreChannel && conn != null && c['connection_id'] != conn) {
      return false;
    }
    final label = req.q('label');
    if (!ignoreLabel && label != null && !(c['tags'] as List).contains(label)) {
      return false;
    }
    final search = req.q('search') ?? req.q('q');
    if (search != null && !_haystack(c).contains(_fold(search.trim()))) {
      return false;
    }
    return true;
  }

  bool _match(Map<String, dynamic> c, DemoRequest req) {
    if (!_baseMatch(c, req)) return false;
    final status = req.q('status');
    if (status != null && c['status'] != status) return false;
    if (_truthy(req.q('unread')) && (c['unread_count'] as int) <= 0) {
      return false;
    }
    final assignee = req.q('assignee');
    if (assignee == 'unassigned' || assignee == 'none') {
      if (c['assignee'] != null) return false;
    } else if (assignee != null) {
      final person = demoPersonById(assignee);
      if (c['assignee'] != (person?.id ?? assignee)) return false;
    }
    final priority = req.q('priority');
    if (priority != null && c['priority'] != priority) return false;
    final pinned = req.q('pinned');
    if (pinned == '1' && c['is_pinned'] != true) return false;
    if (pinned == '0' && c['is_pinned'] == true) return false;
    return true;
  }

  List<Map<String, dynamic>> _sorted(Iterable<Map<String, dynamic>> items) =>
      items.toList()..sort((a, b) {
        final byTime = '${b['last_message_at']}'.compareTo(
          '${a['last_message_at']}',
        );
        return byTime != 0 ? byTime : '${a['id']}'.compareTo('${b['id']}');
      });

  DemoResponse _list(DemoRequest req) {
    _flush();
    final all = _sorted(_convs.values.where((c) => _match(c, req)));
    final perPage = req.qInt('per_page', 30).clamp(1, 100);
    var start = 0;
    final before = req.q('before');
    if (before != null) {
      final at = all.indexWhere((c) => c['id'] == before);
      start = at < 0 ? all.length : at + 1;
    }
    final page = all.skip(start).take(perPage).toList();
    final hasMore = start + page.length < all.length;
    return ok(
      [for (final c in page) _convJson(c)],
      pagination: {
        'per_page': perPage,
        'has_more': hasMore,
        'next_before': hasMore && page.isNotEmpty ? page.last['id'] : null,
      },
    );
  }

  DemoResponse _facets(DemoRequest req) {
    _flush();
    final base = _convs.values.where((c) => _baseMatch(c, req)).toList();
    final open = base.where((c) => c['status'] == 'open').toList();
    final assignees = <String, int>{};
    for (final c in open) {
      final a = c['assignee'] as String?;
      if (a != null) assignees[a] = (assignees[a] ?? 0) + 1;
    }
    final channels = <String, int>{};
    for (final c in _convs.values.where(
      (c) => c['status'] == 'open' && _baseMatch(c, req, ignoreChannel: true),
    )) {
      final ch = c['channel'] as String;
      channels[ch] = (channels[ch] ?? 0) + 1;
    }
    final labels = <String, int>{};
    for (final c in _convs.values.where(
      (c) => c['status'] == 'open' && _baseMatch(c, req, ignoreLabel: true),
    )) {
      for (final t in (c['tags'] as List).cast<String>()) {
        labels[t] = (labels[t] ?? 0) + 1;
      }
    }
    int count(String status) => base.where((c) => c['status'] == status).length;
    return ok({
      'total': open.length,
      'status': {
        'open': count('open'),
        'pending': count('pending'),
        'closed': count('closed'),
      },
      'unread': open.where((c) => (c['unread_count'] as int) > 0).length,
      'urgent': open.where((c) => c['priority'] == 'urgent').length,
      'unassigned': open.where((c) => c['assignee'] == null).length,
      'assignees': assignees,
      'channels': channels,
      'labels': labels,
    });
  }

  DemoResponse _changes(DemoRequest req) {
    _flush();
    final after = int.tryParse(req.q('after') ?? '');
    final only = req.q('conversation_id');
    final data = after == null
        ? const <Map<String, dynamic>>[]
        : [
            for (final (seq, id) in _events)
              if (seq > after && (only == null || only == id))
                {'type': 'conversation', 'conversation_id': id},
          ];
    // `cursor` nằm NGANG `data`, như API thật (INB-I19).
    return DemoResponse(200, {
      'success': true,
      'data': data,
      'cursor': '$_rev',
      'has_more': false,
    });
  }

  DemoResponse _withConv(
    DemoRequest req,
    DemoResponse Function(Map<String, dynamic> c) body,
  ) {
    _flush();
    final c = _convs[req.params['id']];
    if (c == null) return notFound('Không tìm thấy hội thoại.');
    return body(c);
  }

  // ── Tin nhắn ──────────────────────────────────────────────────────────────

  DemoResponse _messages(DemoRequest req) => _withConv(req, (c) {
    final thread = _threads[c['id']]!;
    final perPage = req.qInt('per_page', 30).clamp(1, 100);
    var end = thread.length;
    final before = req.q('before');
    if (before != null) {
      final at = thread.indexWhere((m) => m['id'] == before);
      end = at < 0 ? 0 : at;
    }
    final start = (end - perPage).clamp(0, end);
    final page = thread.sublist(start, end).reversed.toList();
    final hasMore = start > 0;
    return ok(
      page,
      pagination: {
        'per_page': perPage,
        'has_more': hasMore,
        'next_before': hasMore && page.isNotEmpty ? page.last['id'] : null,
      },
    );
  });

  DemoResponse _search(DemoRequest req) => _withConv(req, (c) {
    final q = _fold((req.q('q') ?? '').trim());
    if (q.isEmpty) return ok(const <Object>[]);
    final limit = req.qInt('limit', 50);
    final found = _threads[c['id']]!.reversed
        .where((m) => _fold('${m['text']}').contains(q))
        .take(limit)
        .toList();
    return ok(found);
  });

  Map<String, dynamic>? _findMessage(String convId, String? messageId) {
    for (final m in _threads[convId] ?? const <Map<String, dynamic>>[]) {
      if (m['id'] == messageId) return m;
    }
    return null;
  }

  DemoResponse _send(DemoRequest req) => _withConv(req, (c) {
    final body = req.json;
    final text = '${body['text'] ?? ''}'.trim();
    final clientId = body['client_message_id'] as String?;
    final convId = c['id'] as String;
    final thread = _threads[convId]!;
    // Khoá chống trùng: gửi lại cùng khoá trả đúng tin đã nhận.
    if (clientId != null) {
      for (final m in thread) {
        if (m['client_message_id'] == clientId) return created(m);
      }
    }
    if (text.isEmpty) {
      return unprocessable('Bản demo chỉ gửi được tin chữ.');
    }
    final at = _iso(DateTime.now());
    final message = _message(
      conversationId: convId,
      out: true,
      text: text,
      at: at,
      clientId: clientId,
      replyTo: _findMessage(convId, body['reply_to_message_id'] as String?),
    );
    thread.add(message);
    c['last_message'] = text;
    c['last_message_at'] = at;
    c['updated_at'] = at;
    c['unread_count'] = 0;
    final reply = _autoReplyText[convId];
    if (reply != null && _autoReplied.add(convId)) {
      _pending.add(
        _PendingReply(
          convId,
          DateTime.now().add(const Duration(seconds: 8)),
          reply,
        ),
      );
    }
    return created(message);
  });

  DemoResponse _resend(DemoRequest req) => _withConv(req, (c) {
    final m = _findMessage(c['id'] as String, req.params['mid']);
    if (m == null) return notFound('Không tìm thấy tin này.');
    m['status'] = 'sent';
    m['error'] = null;
    m['error_code'] = null;
    return ok(m);
  });

  DemoResponse _toggleMessagePin(DemoRequest req) => _withConv(req, (c) {
    final m = _findMessage(c['id'] as String, req.params['mid']);
    if (m == null) return notFound('Không tìm thấy tin này.');
    m['pinned'] = m['pinned'] != true;
    // API trả `{success, pinned}` ở gốc (INB-I21).
    return DemoResponse(200, {'success': true, 'pinned': m['pinned']});
  });

  DemoResponse _teamReaction(DemoRequest req) => _withConv(req, (c) {
    final m = _findMessage(c['id'] as String, req.params['mid']);
    if (m == null) return notFound('Không tìm thấy tin này.');
    final emoji = '${req.json['emoji'] ?? ''}';
    final list = (m['team_reactions'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
    final mine = list.indexWhere((e) => e['user_id'] == demoMeId);
    final same = mine >= 0 && list[mine]['emoji'] == emoji;
    if (mine >= 0) list.removeAt(mine);
    if (!same && emoji.isNotEmpty) {
      list.add({
        'user_id': demoMeId,
        'user_name': demoMe.name,
        'emoji': emoji,
        'at': _iso(DateTime.now()),
      });
    }
    m['team_reactions'] = list;
    return ok({'team_reactions': list});
  });

  // ── Thao tác trên hội thoại ───────────────────────────────────────────────

  DemoResponse _assign(DemoRequest req) => _withConv(req, (c) {
    final person = demoPersonById(req.json['assignee_id'] as String?);
    c['assignee'] = person?.id;
    c['assignee_name'] = person?.name;
    c['updated_at'] = _iso(DateTime.now());
    return ok(_convJson(c));
  });

  DemoResponse _update(DemoRequest req) => _withConv(req, (c) {
    final body = req.json;
    final status = body['status'];
    if (status is String &&
        const ['open', 'pending', 'closed'].contains(status)) {
      c['status'] = status;
    }
    final priority = body['priority'];
    if (priority is String) c['priority'] = priority;
    final tags = body['tags'];
    if (tags is List) {
      c['tags'] = [for (final t in tags) '$t'];
      _labels.addAll((c['tags'] as List).cast<String>());
    }
    c['updated_at'] = _iso(DateTime.now());
    return ok(_convJson(c));
  });

  DemoResponse _setLabels(DemoRequest req) {
    final body = req.json;
    final ids = [
      for (final id in (body['conversation_ids'] as List? ?? [])) '$id',
    ];
    final labels = [
      for (final l in (body['labels'] as List? ?? []))
        if ('$l'.trim().isNotEmpty) '$l'.trim(),
    ];
    final mode = '${body['mode'] ?? 'add'}';
    var updated = 0;
    for (final id in ids) {
      final c = _convs[id];
      if (c == null) continue;
      final tags = (c['tags'] as List).cast<String>().toList();
      switch (mode) {
        case 'remove':
          tags.removeWhere(labels.contains);
        case 'replace' || 'set':
          tags
            ..clear()
            ..addAll(labels);
        default:
          for (final l in labels) {
            if (!tags.contains(l)) tags.add(l);
          }
      }
      c['tags'] = tags;
      updated++;
    }
    _labels.addAll(labels);
    return ok({'updated': updated});
  }

  DemoResponse _flagToggle(DemoRequest req, String key, bool on) =>
      _withConv(req, (c) {
        c[key] = on;
        return ok({key: on});
      });

  DemoResponse _block(DemoRequest req, bool on) => _withConv(req, (c) {
    c['blocked_at'] = on ? _iso(DateTime.now()) : null;
    return ok(_convJson(c));
  });

  DemoResponse _convert(DemoRequest req) => _withConv(req, (c) {
    final existing = c['customer_id'] as String?;
    if (existing != null) {
      return ok({
        'customer_id': existing,
        'created': false,
        'linked_existing': true,
      });
    }
    final id =
        links?.createCustomer?.call(
          name: '${c['customer_name'] ?? 'Khách mới'}',
          source: c['channel'] as String?,
        ) ??
        demoNewId();
    c['customer_id'] = id;
    return ok({'customer_id': id, 'created': true, 'linked_existing': false});
  });

  // ── Kênh ──────────────────────────────────────────────────────────────────

  DemoResponse _channels(DemoRequest req) {
    _flush();
    final since = _iso(DateTime.now().subtract(const Duration(hours: 24)));
    return ok([
      for (final conn in _connectionsLive)
        {
          ...conn,
          // Số tin khách gửi tới trong 24 giờ qua trên tài khoản này.
          'today': _convs.values
              .where((c) => c['connection_id'] == conn['id'])
              .expand((c) => _threads[c['id']]!)
              .where(
                (m) =>
                    m['direction'] == 'in' &&
                    '${m['sent_at']}'.compareTo(since) >= 0,
              )
              .length,
        },
    ]);
  }

  // ── Thông báo ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _sortedNotifications() =>
      _notifications.toList()
        ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));

  // ── Bảng route ────────────────────────────────────────────────────────────

  void register(DemoRoutes r) {
    const base = '/inbox/conversations';

    // Đường tĩnh trước `{id}`: `/facets` và `/labels` cùng số đoạn với nó.
    r.get(base, _list);
    r.get('$base/facets', _facets);
    r.post('$base/labels', _setLabels);
    r.get('/inbox/changes', _changes);
    r.get('/inbox/labels', (_) => ok(_labels.toList()..sort()));
    r.get('/inbox/quick-replies', (_) => ok(_quickReplies));
    r.post(
      '/inbox/media',
      (_) => unprocessable(
        'Bản demo chưa gửi được ảnh hay tệp — hãy thử gửi tin chữ.',
      ),
    );

    r.get('$base/{id}', (req) => _withConv(req, (c) => ok(_convJson(c))));
    r.put('$base/{id}', _update);
    r.patch('$base/{id}', _update);
    r.get('$base/{id}/messages', _messages);
    r.post('$base/{id}/messages', _send);
    r.get('$base/{id}/messages/search', _search);
    r.post('$base/{id}/messages/{mid}/pin', _toggleMessagePin);
    r.post('$base/{id}/messages/{mid}/resend', _resend);
    r.post('$base/{id}/messages/{mid}/team-reactions', _teamReaction);
    r.get(
      '$base/{id}/assets',
      (req) => _withConv(
        req,
        (_) => ok({
          'media': <Object>[],
          'files': <Object>[],
          'links': <Object>[],
          'pagination': {
            'per_page': 80,
            'has_more': false,
            'next_before': null,
          },
        }),
      ),
    );
    r.get(
      '$base/{id}/context',
      (req) => _withConv(
        req,
        (c) => ok({
          'opportunities': <Object>[],
          'timeline': [
            {
              'kind': 'event',
              'type': 'conversation_started',
              'text': 'Khách bắt đầu trò chuyện',
              'at': c['created_at'],
            },
          ],
        }),
      ),
    );
    r.post(
      '$base/{id}/read',
      (req) => _withConv(req, (c) {
        c['unread_count'] = 0;
        return ok({'unread_count': 0});
      }),
    );
    r.post(
      '$base/{id}/unread',
      (req) => _withConv(req, (c) {
        if ((c['unread_count'] as int) < 1) c['unread_count'] = 1;
        return ok({'unread_count': c['unread_count']});
      }),
    );
    r.post('$base/{id}/pin', (req) => _flagToggle(req, 'is_pinned', true));
    r.delete('$base/{id}/pin', (req) => _flagToggle(req, 'is_pinned', false));
    r.post('$base/{id}/mute', (req) => _flagToggle(req, 'is_muted', true));
    r.delete('$base/{id}/mute', (req) => _flagToggle(req, 'is_muted', false));
    r.post('$base/{id}/block', (req) => _block(req, true));
    r.delete('$base/{id}/block', (req) => _block(req, false));
    r.post('$base/{id}/assign', _assign);
    r.post('$base/{id}/convert', _convert);

    // Kênh. Bản demo không nối được tài khoản thật: OAuth/ghép nối báo rõ lý
    // do thay vì mở trình duyệt hay chờ một agent không tồn tại.
    r.get('/channels', _channels);
    r.post(
      '/channels/pair/start',
      (_) => unprocessable(
        'Bản demo không ghép nối được tài khoản Zalo thật. Hãy dùng bản '
        'chính thức để kết nối kênh.',
      ),
    );
    r.get(
      '/channels/pair/{id}/status',
      (_) => ok({'status': 'expired', 'stage': 'error'}),
    );
    r.get(
      '/channels/{channel}/oauth/redirect',
      (_) => unprocessable(
        'Bản demo không kết nối được kênh thật. Hãy dùng bản chính thức để '
        'kết nối Facebook, Zalo OA hay TikTok.',
      ),
    );
    r.delete('/channels/{id}', (req) {
      final before = _connectionsLive.length;
      _connectionsLive.removeWhere((c) => c['id'] == req.params['id']);
      return _connectionsLive.length == before
          ? notFound('Không tìm thấy kênh.')
          : noContent;
    });

    // Thông báo.
    r.get('/notifications', (req) {
      _flush();
      final unreadOnly = _truthy(req.q('unread'));
      return paged(req, [
        for (final n in _sortedNotifications())
          if (!unreadOnly || n['read_at'] == null) n,
      ]);
    });
    r.get('/notifications/unread-count', (_) {
      _flush();
      return ok({
        'count': _notifications.where((n) => n['read_at'] == null).length,
      });
    });
    r.post('/notifications/mark-all-read', (_) {
      final now = _iso(DateTime.now());
      for (final n in _notifications) {
        n['read_at'] ??= now;
      }
      return ok(const <String, Object>{});
    });
    r.post('/notifications/{id}/mark-read', (req) {
      for (final n in _notifications) {
        if (n['id'] == req.params['id']) {
          n['read_at'] ??= _iso(DateTime.now());
          return ok(n);
        }
      }
      return notFound('Không tìm thấy thông báo.');
    });
  }
}
