import 'package:flutter/material.dart';

/// Palette, straight from the Sleek design system for this app
/// (`design/html/*.html`, `:root` block). Values here and there must stay equal —
/// when the design changes, change this file, not individual widgets.
abstract final class OmniColors {
  // ---- Brand -------------------------------------------------------------
  /// Mòng két. Dành cho hành động chính, hero đăng nhập và tab đang chọn.
  ///
  /// Thay chàm #5B5CE2. Chàm không xấu — nó là màu mặc định của Tailwind và
  /// Material, gặp ở mọi app SaaS. Mòng két giữ cùng họ lạnh (thợ đã quen
  /// xanh lá của myXteam nên không thấy lạ) nhưng bão hoà thấp hơn hẳn.
  ///
  /// 5.73:1 trên nền trang, 6.12:1 trên thẻ — xem `contrast_test.dart`.
  static const primary = Color(0xFF0F6E63);
  static const primaryForeground = Color(0xFFFFFFFF);

  /// The brand gradient's far end — used only inside [OmniGradients].
  static const primaryGlow = Color(0xFF3FA294);

  /// Nền rất nhạt sau bề mặt được chọn / nhấn nhẹ.
  static const accent = Color(0xFFE4F1EF);
  static const accentForeground = Color(0xFF0C5D54);

  // ---- Surfaces ----------------------------------------------------------
  static const background = Color(0xFFF5F8F7);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFEDF3F1);
  static const secondary = Color(0xFFE4F1EF);

  /// Đường kẻ TRANG TRÍ: mép thẻ, vạch ngăn dòng.
  ///
  /// 1.25:1 trên thẻ — nhạt một cách cố ý. Thẻ đã tự tách khỏi nền nhờ nền
  /// trắng đặt trên nền ngả xanh, nên đường viền chỉ làm sắc mép chứ không
  /// gánh việc nhận diện. Ranh giới nào PHẢI nhận ra được thì dùng
  /// [borderInteractive].
  static const border = Color(0xFFDFE8E6);

  /// Ranh giới của thành phần TƯƠNG TÁC: ô nhập, nút viền, chip chưa chọn.
  ///
  /// WCAG 1.4.11 đòi 3:1 cho ranh giới cần thiết để nhận ra một thành phần.
  /// #7F918C là giá trị nhạt nhất còn đạt (3.32 trên thẻ, 3.10 trên nền) —
  /// chọn nhạt nhất để ô nhập không đọc như một cái khung nặng.
  static const borderInteractive = Color(0xFF7F918C);

  // ---- Text --------------------------------------------------------------
  static const foreground = Color(0xFF151E1C);
  static const secondaryForeground = Color(0xFF2E3A37);

  /// Chữ phụ.
  ///
  /// #777889 cũ chỉ đạt 4.10:1 trên nền trang, dưới ngưỡng AA — ở 82 chỗ trong
  /// app. Giá trị này đạt 5.26:1 trên nền trang và 5.62:1 trên thẻ, mà mắt
  /// thường gần như không thấy khác.
  static const mutedForeground = Color(0xFF5A6B67);

  // ---- Semantic ----------------------------------------------------------
  //
  // KHÔNG có `successText`, và đó là một quyết định chứ không phải thiếu sót.
  //
  // Mọi ứng viên xanh lá đủ tối để làm chữ (#067A55, #157A33, #1B7F33,
  // #2E7D32) chỉ chênh [primary] 1.13–1.20 lần về ĐỘ SÁNG. Người bị mù màu
  // lục-đỏ — khoảng 8% nam giới, mà xưởng thì gần như toàn nam — nhìn hai màu
  // đó gần như một. Độ sáng cũng là thứ duy nhất còn lại khi nhìn màn hình
  // dưới nắng.
  //
  // Nên "đã xong" dùng chính [primary], cộng dấu tick ĐẶC và chữ làm nhạt đi.
  // Trạng thái đọc được qua hình dạng, không chỉ qua màu — cũng chính là điều
  // WCAG 1.4.1 đòi hỏi. `contrast_test.dart` ghi lại phép đo này.
  //
  // [success] ở lại cho ĐỒ HOẠ: thanh tiến độ, chấm trạng thái, vòng tiến
  // trình. Đồ hoạ không đứng cạnh chữ teal nên không bị nhầm với nó.
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  /// NỀN xanh dương mang chữ trắng.
  ///
  /// [info] là màu ĐỒ HOẠ — chấm, icon, viền trái. Chữ trắng trên nó chỉ đạt
  /// 2.77:1, nên nó không bao giờ được làm nền cho chữ. Cùng cái bẫy đã bắt
  /// [dangerSurface] ra đời.
  static const infoSurface = Color(0xFF0369A1);

  // Bản đậm hơn của hai màu trên, dành riêng cho CHỮ. Bản gốc đạt lần lượt
  // 2.15:1 và 3.76:1 trên nền trắng — tốt để tô, không đủ để đọc.
  //
  // Giữ cả hai vì đây là hai việc khác nhau: icon lớn, thanh tiến độ, chấm
  // trạng thái vẫn dùng bản gốc để không bị xỉn đi. Một cái NỀN mang chữ trắng
  // thì tính là chữ — badge đỏ chữ trắng chỉ đạt 3.76:1 với bản gốc.
  static const warningText = Color(0xFF9A6206);
  static const dangerText = Color(0xFFC2251C);

  /// Bản dùng ở nền tối. Nền tối làm mọi màu phải SÁNG lên chứ không tối đi —
  /// #9A6206 trên #16211E chỉ đạt 2.34:1.
  static const warningTextDark = Color(0xFFE8A33D);
  static const dangerTextDark = Color(0xFFFF6B60);

  /// NỀN đỏ mang chữ trắng: chấm đếm chưa đọc, badge số.
  ///
  /// Cùng giá trị với [dangerText] nhưng khác vai, nên khác tên: cái này
  /// KHÔNG đổi theo chế độ tối. Dùng [dangerTextDark] làm nền thì chữ trắng
  /// trên đó chỉ đạt 2.6:1 — sáng hơn không phải lúc nào cũng đúng, còn tuỳ
  /// màu đó đang là chữ hay đang là nền.
  static const dangerSurface = Color(0xFFC2251C);

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

  // ---- Dark theme --------------------------------------------------------
  //
  // Nền tối ngả xanh cùng hướng với bảng sáng, không phải navy như bản chàm
  // cũ: hai chế độ phải đọc ra là cùng một sản phẩm.
  static const darkBackground = Color(0xFF0E1614);
  static const darkCard = Color(0xFF16211E);
  static const darkMuted = Color(0xFF1E2A27);
  static const darkBorder = Color(0xFF27332F);

  /// Bản tối của [borderInteractive]. 3.02:1 trên thẻ tối.
  static const darkBorderInteractive = Color(0xFF5C6D68);

  /// Bản tối của [accent] và [accentForeground].
  ///
  /// [accent] #E4F1EF là một khối sáng chói nếu đặt giữa màn hình tối — nền
  /// nhấn phải TỐI đi cùng chiều với nền trang, chứ không giữ nguyên.
  static const darkAccent = Color(0xFF123A34);
  static const darkAccentForeground = Color(0xFF9FE3D6);

  static const darkForeground = Color(0xFFEAF2F0);
  static const darkMutedForeground = Color(0xFF9AAAA6);
  static const darkPrimary = Color(0xFF4FBFAE);

  /// Chữ trên nút chính ở nền tối.
  ///
  /// Nền tối buộc [darkPrimary] phải sáng, và chữ trắng trên #4FBFAE chỉ đạt
  /// 2.18:1. Nên ở chế độ tối, chữ trên nút chính là chữ TỐI — đây là chỗ hai
  /// chế độ buộc phải khác nhau, không phải chỗ đảo màu là xong.
  static const darkPrimaryForeground = Color(0xFF06231F);

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

  /// Deterministic avatar tint from a name, so the same person keeps the same
  /// colour on every screen.
  static const avatarPalette = <Color>[
    Color(0xFF4338CA),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  static Color avatarFor(String seed) {
    if (seed.isEmpty) return avatarPalette.first;
    final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return avatarPalette[hash % avatarPalette.length];
  }
}
