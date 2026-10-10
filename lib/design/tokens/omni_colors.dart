import 'package:flutter/material.dart';

/// Bảng màu "Orbit" — nguồn là artifact giao diện đã duyệt (`Main.dc.html`
/// trong bộ UI kit). Web và app dùng CÙNG bảng này: đổi thiết kế thì đổi file
/// này, không đổi từng widget.
///
/// Mọi cặp chữ/nền được đo trong `contrast_test.dart`, không đo bằng mắt.
abstract final class OmniColors {
  // ---- Nhận diện ----------------------------------------------------------
  /// Mực. Chữ chính, ô logo, thanh bên tối, màn mở app.
  static const ink = Color(0xFF0B1A33);

  /// Nền của ô logo khi logo nằm TRÊN một mặt mực (màn đăng nhập, màn mở app):
  /// cùng họ với [ink] nhưng sáng hơn một bậc để ô còn tách khỏi nền.
  static const inkRaised = Color(0xFF132744);

  /// Chữ phụ đặt trên nền [ink] (8.46:1): dòng giới thiệu màn đăng nhập, câu
  /// khẩu hiệu màn mở app.
  static const inkMutedForeground = Color(0xFFA9B6CA);

  /// Nét trang trí trên nền [ink]: các vòng quỹ đạo sau tiêu đề đăng nhập.
  static const inkLine = Color(0xFF1F3A5F);

  /// Số "quá hạn" trên thẻ mực (đỏ sáng, 7.6:1 trên mực).
  static const dangerOnInk = Color(0xFFFF8A80);

  /// Hai quầng tròn đồng tâm sau logo ở màn mở app — ngoài sáng hơn trong.
  static const inkHaloOuter = Color(0xFF10284A);
  static const inkHaloInner = Color(0xFF0E2240);

  /// Quỹ đạo sáng. CHỈ cho đồ hoạ: nét logo, thanh tiến độ, chữ trên nền mực.
  ///
  /// Trên nền sáng nó chỉ đạt khoảng 1.9:1 — không bao giờ làm chữ hay nền
  /// mang chữ trắng ở chế độ sáng.
  static const orbit = Color(0xFF14D3C8);

  /// Mặt trời. Chấm "tin mới" của logo và huy hiệu CHƯA ĐỌC — chỉ hai chỗ đó
  /// được dùng màu vàng, để vàng luôn có nghĩa là "có cái mới".
  ///
  /// Chữ trên nó là [ink] (10.9:1), không phải trắng.
  static const sun = Color(0xFFFFC43D);
  static const sunForeground = ink;

  // ---- Màu chính ----------------------------------------------------------
  /// Quỹ đạo. Nút chính, liên kết, tab đang chọn.
  ///
  /// 4.99:1 trên thẻ, 4.65:1 trên nền trang — xem `contrast_test.dart`.
  static const primary = Color(0xFF0A7D76);
  static const primaryForeground = Color(0xFFFFFFFF);

  /// Nút chính khi đang nhấn, và màu chữ/icon của tab đang chọn (đặt trên
  /// [accent] thì cần tối hơn [primary] một bậc mới đọc rõ).
  static const primaryPressed = Color(0xFF075E59);

  /// Nền nhạt sau bề mặt được chọn: viên tab đang chọn, ô icon khu Công việc,
  /// chip xem trước trên màn chọn tab.
  static const accent = Color(0xFFDDF5F2);
  static const accentForeground = primaryPressed;

  /// Bản nhạt hơn nữa của [accent] — vầng sáng quanh ô nhập đang focus.
  static const accentSoft = Color(0xFFE3F8F6);

  // ---- Bề mặt -------------------------------------------------------------
  static const background = Color(0xFFF5F7FA);
  static const card = Color(0xFFFFFFFF);

  /// Bề mặt trung tính: nền ô icon khu Quản trị, rãnh của bộ chọn phân đoạn,
  /// vòng tròn của màn "không có quyền".
  static const muted = Color(0xFFEEF1F5);
  static const secondary = accent;

  /// Đường kẻ TRANG TRÍ: mép thẻ, vạch ngăn dòng.
  ///
  /// Nhạt một cách cố ý — thẻ trắng trên nền xám đã tự tách khỏi nền, đường
  /// viền chỉ làm sắc mép. Ranh giới nào PHẢI nhận ra được thì dùng
  /// [borderInteractive].
  static const border = Color(0xFFE3E8EF);

  /// Vạch ngăn giữa các dòng BÊN TRONG một thẻ — nhạt hơn [border] một chút.
  static const divider = Color(0xFFEEF1F5);

  /// Viền của nút phụ và ô chọn chưa chọn trong biểu mẫu (#C9D2DE,
  /// `SPrinciples.dc.html` §5). Đậm hơn [border] để đọc ra là bấm được, nhạt
  /// hơn [borderInteractive] — viền ô NHẬP mới phải đạt 3:1.
  static const controlBorder = Color(0xFFC9D2DE);

  /// [controlBorder] theo chế độ đang bật.
  static Color controlBorderOf(BuildContext context) =>
      _byBrightness(context, controlBorder, darkBorderInteractive);

  /// Rãnh của thanh tiến độ mảnh (#EEF1F5 / tối: darkMuted).
  static Color trackOf(BuildContext context) =>
      _byBrightness(context, muted, darkMuted);

  /// Đoạn "còn lại" của thanh tiến độ (#C9D2DE / tối: darkBorderInteractive).
  static Color mutedBarOf(BuildContext context) =>
      _byBrightness(context, controlBorder, darkBorderInteractive);

  /// Ranh giới của thành phần TƯƠNG TÁC: ô nhập, nút viền, chip chưa chọn.
  ///
  /// Thiết kế ghi #8A97AB, nhưng giá trị đó chỉ đạt 2.96:1 trên thẻ và 2.76:1
  /// trên nền — dưới ngưỡng 3:1 của WCAG 1.4.11. #8390A5 là bản gần nhất còn
  /// đạt (3.23 trên thẻ, 3.01 trên nền); mắt thường không phân biệt được.
  static const borderInteractive = Color(0xFF8390A5);

  // ---- Chữ ----------------------------------------------------------------
  static const foreground = ink;
  static const secondaryForeground = Color(0xFF3A4760);

  /// Chữ phụ. 5.65:1 trên nền trang, 6.07:1 trên thẻ.
  static const mutedForeground = Color(0xFF56637A);

  // ---- Ngữ nghĩa ----------------------------------------------------------
  //
  // KHÔNG có `successText`, và đó là một quyết định chứ không phải thiếu sót.
  //
  // Mọi ứng viên xanh lá đủ tối để làm chữ (#067A55, #157A33, #1B7F33,
  // #2E7D32) chỉ chênh [primary] 1.02–1.09 lần về ĐỘ SÁNG. Người bị mù màu
  // lục-đỏ nhìn hai màu đó gần như một. Nên "đã xong" dùng chính [primary],
  // cộng dấu tick ĐẶC. `contrast_test.dart` ghi lại phép đo này.
  //
  // [success] ở lại cho ĐỒ HOẠ: thanh tiến độ, chấm trạng thái.
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  /// Chấm "quá hạn trả lời" ở hộp thư — hổ phách, cạnh chấm đỏ "khẩn".
  static const sla = Color(0xFFE0A100);

  /// Nguy — đồ hoạ và viền lỗi của ô nhập (5.32:1 trên thẻ).
  static const destructive = Color(0xFFC8322A);

  /// Thông tin — đồ hoạ.
  static const info = Color(0xFF2456D6);

  /// NỀN xanh dương mang chữ trắng (6.22:1).
  static const infoSurface = Color(0xFF2456D6);

  /// Cặp nền nhạt / chữ đậm cho khu Trao đổi và nhãn thông tin.
  static const infoSoft = Color(0xFFE6EDFD);
  static const infoText = Color(0xFF1D46B0);

  /// Cặp nền nhạt / chữ đậm cho khu Bán hàng và nhãn cảnh báo.
  static const warningSoft = Color(0xFFFFF4D6);

  // Bản đậm của cảnh báo/nguy, dành riêng cho CHỮ.
  static const warningText = Color(0xFF7A4F00);
  static const dangerText = Color(0xFFA32720);

  /// Nền nhạt của hộp báo lỗi (chữ [dangerText] trên nó đạt 6.40:1).
  static const dangerSoft = Color(0xFFFDECEA);

  /// Ghi chú nội bộ (hộp thư, hồ sơ khách): nền vàng giấy, viền vàng đậm hơn.
  static const noteSurface = Color(0xFFFFF6DB);
  static const noteBorder = Color(0xFFF3D78A);

  /// Viền của nút "Đăng xuất" — ranh giới trang trí, nhạt, mang sắc đỏ.
  static const dangerBorder = Color(0xFFE7B6B1);

  /// Bản dùng ở nền tối. Nền tối làm mọi màu phải SÁNG lên chứ không tối đi.
  static const warningTextDark = Color(0xFFE8A33D);
  static const dangerTextDark = Color(0xFFFF6B60);

  /// NỀN đỏ mang chữ trắng: huy hiệu việc trễ hạn, badge số cảnh báo.
  ///
  /// KHÔNG đổi theo chế độ tối: dùng [dangerTextDark] làm nền thì chữ trắng
  /// trên đó không đạt — sáng hơn không phải lúc nào cũng đúng, còn tuỳ màu đó
  /// đang là chữ hay đang là nền.
  static const dangerSurface = Color(0xFFC8322A);

  /// Chữ cảnh báo, đã chọn theo chế độ sáng/tối đang bật.
  ///
  /// Dùng cái này chứ đừng viết thẳng [warningText]: một hằng số ghim vào
  /// chế độ sáng là cách app này đã từng có 30 chỗ chữ không đọc được ở chế
  /// độ tối.
  static Color warningTextOf(BuildContext context) =>
      _byBrightness(context, warningText, warningTextDark);

  /// Chữ nguy hiểm, đã chọn theo chế độ sáng/tối đang bật.
  static Color dangerTextOf(BuildContext context) =>
      _byBrightness(context, dangerText, dangerTextDark);

  static Color _byBrightness(BuildContext context, Color light, Color dark) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ---- Chế độ tối ---------------------------------------------------------
  //
  // Nền tối là mực ngả xanh đêm, cùng họ với [ink]: hai chế độ phải đọc ra là
  // cùng một sản phẩm.
  static const darkBackground = Color(0xFF0B1422);
  static const darkCard = Color(0xFF121E30);
  static const darkMuted = Color(0xFF1A2840);
  static const darkBorder = Color(0xFF22324A);

  /// Bản tối của [borderInteractive].
  ///
  /// Phải đạt 3:1 trên CẢ HAI mặt nó có thể nằm lên: [darkCard] (3.73) và
  /// [darkMuted] (3.29) — ô nhập ở chế độ tối tô nền bằng cái thứ hai.
  static const darkBorderInteractive = Color(0xFF667894);

  /// Bản tối của [accent] và [accentForeground]: nền nhấn phải TỐI đi cùng
  /// chiều với nền trang, chứ không giữ nguyên khối sáng.
  static const darkAccent = Color(0xFF0E3438);
  static const darkAccentForeground = Color(0xFF9FEDE6);

  /// Bản tối của các cặp nền nhạt / chữ đậm theo khu: ô icon trong "Tất cả",
  /// ô chữ viết tắt ở màn chọn không gian, nhãn trạng thái. Nền nhạt của chế
  /// độ sáng là khối chói trên nền tối, nên nền tối đi và chữ sáng lên.
  static const darkInfoSoft = Color(0xFF17264A);
  static const darkInfoText = Color(0xFF9DB6F5);
  static const darkWarningSoft = Color(0xFF3A2E12);

  /// Nền dòng thông báo chưa đọc (`Notifications.dc.html`); tối dùng primary
  /// alpha .08.
  static const unreadRow = Color(0xFFF3FAF9);

  /// Chọn bản sáng/tối của một cặp màu theo chế độ đang bật.
  static Color byBrightness(BuildContext context, Color light, Color dark) =>
      _byBrightness(context, light, dark);

  static const darkForeground = Color(0xFFE8EEF6);
  static const darkMutedForeground = Color(0xFF9AA8BD);
  static const darkPrimary = Color(0xFF2EE0D5);

  /// Chữ trên nút chính ở nền tối.
  ///
  /// Nền tối buộc [darkPrimary] phải sáng, nên chữ trên nút chính là chữ TỐI
  /// (9.30:1) — đây là chỗ hai chế độ buộc phải khác nhau, không phải chỗ đảo
  /// màu là xong.
  static const darkPrimaryForeground = Color(0xFF062A28);

  // ---- Chat ---------------------------------------------------------------
  /// Messaging surfaces follow Zalo's visual language rather than the CRM
  /// palette above.
  ///
  /// Reps live in this screen all day beside the real Zalo app, and every
  /// difference reads as a defect: the indigo card list looked like a database
  /// table, not a chat. So the inbox and the thread borrow Zalo's blue, its flat
  /// white rows and its pale blue-grey thread canvas. The CRM palette still owns
  /// every other module — this is a deliberate, contained exception.
  static const chatPrimary = Color(0xFF0068FF);

  /// Thread canvas. Bubbles must read as raised against it, which they cannot do
  /// on white — the reason the old thread felt flat.
  static const chatCanvas = Color(0xFFE7EBF0);

  /// Outgoing bubble: pale blue with DARK text. Zalo does not invert to white
  /// text, and dark-on-pale keeps long messages comfortable to read.
  static const chatOutbound = Color(0xFFCFE9FF);

  /// Incoming bubble.
  static const chatInbound = Color(0xFFFFFFFF);

  /// Timestamps and delivery ticks inside a bubble.
  static const chatMeta = Color(0xFF7589A3);

  /// Hairline between list rows, indented past the avatar.
  static const chatDivider = Color(0xFFF0F1F4);

  /// Unread count pill.
  static const chatUnread = Color(0xFFFF3B30);

  // ---- Chat, dark ---------------------------------------------------------
  /// Zalo's dark mode is near-black, not the navy the CRM dark theme uses, and
  /// its outgoing bubble is a MUTED blue-grey rather than a saturated blue —
  /// a bright bubble is exhausting to read a long thread on a black canvas.
  static const chatCanvasDark = Color(0xFF000000);
  static const chatOutboundDark = Color(0xFF3A4A5C);
  static const chatInboundDark = Color(0xFF2A2A2C);
  static const chatMetaDark = Color(0xFF8E8E93);
  static const chatDividerDark = Color(0xFF1C1C1E);

  /// Resolve a chat colour for the active brightness. Every chat surface goes
  /// through here so light and dark can never drift apart.
  static Color chat(BuildContext context, Color light, Color dark) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Avatar chữ tắt: nền xám trung tính, chữ cấp 2 (đo trong contrast_test).
  ///
  /// Không tô màu theo tên nữa. Bảy màu đậm cho bảy người là trang trí — màu
  /// trong app chỉ được nói trạng thái và hành động chính. Có ảnh thì dùng ảnh.
  static const avatarSurface = border;
  static const avatarForeground = secondaryForeground;

  /// Bản tối: nền nâng một bậc, chữ phụ sáng.
  static const darkAvatarSurface = darkMuted;
  static const darkAvatarForeground = darkMutedForeground;
}
