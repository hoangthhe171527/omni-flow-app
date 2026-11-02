import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/finance/domain/finance_models.dart';
import 'package:omni_app/modules/finance/domain/smart_expense_parser.dart';

void main() {
  group('SmartExpenseParser', () {
    test('parseAmountToken nhận diện số tiền tiếng Việt viết tắt', () {
      expect(SmartExpenseParser.parseAmountToken('650k'), 650000);
      expect(SmartExpenseParser.parseAmountToken('12tr'), 12000000);
      expect(SmartExpenseParser.parseAmountToken('1.85tr'), 1850000);
      expect(SmartExpenseParser.parseAmountToken('2.45tr'), 2450000);
      expect(SmartExpenseParser.parseAmountToken('4tr5'), 4500000);
      expect(SmartExpenseParser.parseAmountToken('1tr250'), 1250000);
      expect(SmartExpenseParser.parseAmountToken('2.450.000'), 2450000);
    });

    test('parse 5 khoản cố định chuẩn (Chi phí kho, Điện nước, Lương nhân sự, Lãi vay, Lương kế toán dịch vụ)', () {
      final r1 = SmartExpenseParser.parse(
        'Chi phí kho 12tr',
        groups: FinanceSeedCatalog.defaultGroups,
        accounts: FinanceSeedCatalog.defaultAccounts,
      );
      expect(r1.title, 'Chi phí kho');
      expect(r1.amount, 12000000);
      expect(r1.matchedGroupId, 'op');

      final r2 = SmartExpenseParser.parse(
        'Lãi vay 6.5tr',
        groups: FinanceSeedCatalog.defaultGroups,
        accounts: FinanceSeedCatalog.defaultAccounts,
      );
      expect(r2.title, 'Lãi vay');
      expect(r2.amount, 6500000);
      expect(r2.matchedGroupId, 'fn');

      final r3 = SmartExpenseParser.parse(
        'Lương kế toán dịch vụ 3tr',
        groups: FinanceSeedCatalog.defaultGroups,
        accounts: FinanceSeedCatalog.defaultAccounts,
      );
      expect(r3.title, 'Lương kế toán dịch vụ');
      expect(r3.amount, 3000000);
      expect(r3.matchedGroupId, 'ad');
    });

    test(
      'parse "Tiếp khách 650k tm" nhận diện nguồn Tiền mặt và nhóm Tiếp thị (mk)',
      () {
        final res = SmartExpenseParser.parse(
          'Tiếp khách 650k tm',
          groups: FinanceSeedCatalog.defaultGroups,
          accounts: FinanceSeedCatalog.defaultAccounts,
        );
        expect(res.title, 'Tiếp khách');
        expect(res.amount, 650000);
        expect(res.matchedGroupId, 'mk');
        expect(res.matchedAccountId, 'acc_cash');
      },
    );

    test('parse "12tr tiền thuê mặt bằng nợ" nhận diện trạng thái Chưa trả', () {
      final res = SmartExpenseParser.parse(
        '12tr tiền thuê mặt bằng nợ',
        groups: FinanceSeedCatalog.defaultGroups,
        accounts: FinanceSeedCatalog.defaultAccounts,
      );
      expect(res.title, 'Tiền thuê mặt bằng');
      expect(res.amount, 12000000);
      expect(res.matchedGroupId, 'op');
      expect(res.suggestedStatus, ExpenseStatus.unpaid);
    });
  });
}
