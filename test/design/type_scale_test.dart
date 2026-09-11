import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

/// Không cỡ chữ nào trong thang chung dưới 12.
///
/// `micro` từng là 11 và đi vào `labelSmall` — dòng phụ của mọi dòng việc
/// ("KAWAI HAT-5 · Phục chế T9"), nhãn thanh điều hướng, giờ trên thẻ. Tiếng
/// Việt xếp dấu cả trên lẫn dưới thân chữ (ế, ộ, ữ, ằ); ở 11px, dấu là một
/// vệt và "Hằng" với "Hắng" đọc như nhau ở khoảng cách một cánh tay ngoài
/// xưởng. 12 là sàn của mọi hướng dẫn trợ năng cho chữ đọc được, và là sàn
/// của app này từ đây.
void main() {
  const floor = 12.0;

  final scale = <String, TextStyle>{
    'displayLg': OmniType.displayLg,
    'title': OmniType.title,
    'section': OmniType.section,
    'overline': OmniType.overline,
    'bodyStrong': OmniType.bodyStrong,
    'body': OmniType.body,
    'caption': OmniType.caption,
    'micro': OmniType.micro,
    'money': OmniType.money,
    'moneyHero': OmniType.moneyHero,
  };

  for (final entry in scale.entries) {
    test('${entry.key} không dưới ${floor.toInt()}px', () {
      expect(
        entry.value.fontSize,
        greaterThanOrEqualTo(floor),
        reason:
            '${entry.key} = ${entry.value.fontSize}. Đây là sàn đọc được, '
            'không phải sở thích — muốn nhỏ hơn thì bỏ dòng chữ đó đi, đừng '
            'thu nó lại.',
      );
    });
  }

  test('labelSmall của theme cũng đứng trên sàn', () {
    // Đây là khe mà `micro` đi vào, và là style phần lớn màn hình gọi tới
    // qua `text.labelSmall` chứ không gọi `OmniType.micro` trực tiếp.
    final theme = OmniType.textTheme(
      OmniColors.foreground,
      OmniColors.mutedForeground,
    );

    expect(theme.labelSmall?.fontSize, greaterThanOrEqualTo(floor));
  });

  test('thang vẫn có thứ bậc: micro < caption < body', () {
    // Nâng sàn không được san phẳng thang. Nếu micro đuổi kịp caption thì
    // dòng phụ và dòng chính của một thẻ trông như nhau.
    expect(OmniType.micro.fontSize!, lessThan(OmniType.caption.fontSize!));
    expect(OmniType.caption.fontSize!, lessThan(OmniType.body.fontSize!));
  });
}
