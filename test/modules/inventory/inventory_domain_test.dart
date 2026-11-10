import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/domain/inventory_format.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Logic thuần của Kho: định dạng, việc tiếp theo, gom model, chuẩn hoá
/// serial, map JSON đúng khoá API (thiếu khoá = mất dữ liệu lặng).
void main() {
  InventoryUnit unit(
    String id, {
    String maker = 'YAMAHA',
    String model = 'U3H',
    UnitSale sale = UnitSale.available,
    String? customerId,
    String? customerName,
    bool retail = false,
    double? list,
    double? reserved,
    String? category,
    double? yen,
  }) => InventoryUnit(
    id: id,
    lotId: 'l1',
    maker: maker,
    model: model,
    sale: sale,
    customerId: customerId,
    customerName: customerName,
    retailHold: retail,
    listPrice: list,
    reservedPrice: reserved,
    category: category,
    yenPrice: yen,
  );

  group('định dạng', () {
    test('số đủ chữ số, dấu chấm hàng nghìn', () {
      expect(InventoryFormat.number(12500000), '12.500.000');
      expect(InventoryFormat.number(null), '—');
      expect(InventoryFormat.yen(1850000), '1.850.000 ¥');
    });

    test('tỷ lệ: số nguyên giữ nguyên, lẻ thì 2 chữ số dấu phẩy', () {
      expect(InventoryFormat.rate(200), '200');
      expect(InventoryFormat.rate(185.531), '185,53');
      expect(InventoryFormat.rate(199.999), '200');
      expect(InventoryFormat.rate(null), '—');
    });

    test('ngày và tuổi tồn', () {
      expect(InventoryFormat.dmy('2026-08-17'), '17/08/2026');
      expect(InventoryFormat.dmy('2026-08-17T10:00:00+07:00'), '17/08/2026');
      expect(InventoryFormat.dmy(null), '—');
      final today = DateTime(2026, 11, 9);
      expect(InventoryFormat.ageDays('2026-08-17', today), 84);
      expect(InventoryFormat.ageDays(null, today), isNull);
      expect(InventoryFormat.isoDay(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('tuổi tồn theo nhóm', () {
      expect(AgeBucket.upTo90.matches(90), isTrue);
      expect(AgeBucket.upTo180.matches(91), isTrue);
      expect(AgeBucket.over180.matches(181), isTrue);
      expect(AgeBucket.none.matches(null), isTrue);
      expect(AgeBucket.upTo90.matches(null), isFalse);
    });

    test('chuẩn hoá serial như API: cắt trắng, viết hoa, bỏ đuôi .0', () {
      expect(InventoryFormat.normalizeSerial(' 6100656.0 '), '6100656');
      expect(InventoryFormat.normalizeSerial('jcmo01175'), 'JCMO01175');
      expect(InventoryFormat.normalizeSerial('12.00'), '12');
      expect(InventoryFormat.normalizeSerial('   '), isNull);
      expect(InventoryFormat.normalizeSerial(null), isNull);
    });

    test('tiền gõ tay và số điện thoại', () {
      expect(InventoryFormat.parseMoney('12.500.000 đ'), 12500000);
      expect(InventoryFormat.parseMoney('abc'), isNull);
      // Số dán từ Excel có phần lẻ không bị nhân 10.
      expect(InventoryFormat.parseMoney('5500000.0'), 5500000);
      expect(InventoryFormat.parseMoney('1,234.50'), 1235);
      expect(InventoryFormat.parseMoney('120,000'), 120000);
      expect(InventoryFormat.parseMoney('120.000'), 120000);
      expect(InventoryFormat.parseMoney('-5'), isNull);
      expect(InventoryFormat.looksLikePhone('0909 778'), isTrue);
      expect(InventoryFormat.looksLikePhone('Anh Bình'), isFalse);
    });
  });

  group('việc tiếp theo của lô', () {
    Lot lot({
      LotStatus status = LotStatus.inTransit,
      int units = 10,
      bool fin = false,
      double? due,
      int planned = 0,
      int inStock = 0,
    }) => Lot(
      id: 'l',
      code: 'Ep 64',
      status: status,
      units: units,
      costFinal: fin,
      dueJpy: due,
      plannedCount: planned,
      inStock: inStock,
    );

    test('lô đã về kho: còn bao nhiêu cây', () {
      expect(
        nextStep(lot(status: LotStatus.received, inStock: 7), canPay: true),
        const NextStep(NextTone.muted, 'Còn 7 cây trong kho'),
      );
    });

    test('chưa có cây: chờ packing list', () {
      expect(nextStep(lot(units: 0), canPay: true).text, 'Chờ packing list');
    });

    test('đã chốt giá vốn', () {
      expect(
        nextStep(lot(fin: true), canPay: false).text,
        'Đã chốt giá vốn · chờ nhận hàng',
      );
      expect(
        nextStep(lot(fin: true, status: LotStatus.ordered), canPay: false).text,
        'Đã chốt giá vốn',
      );
    });

    test('còn nợ ¥: người có quyền trả thấy số, người khác không', () {
      expect(
        nextStep(lot(due: 1850000), canPay: true),
        const NextStep(NextTone.warn, 'Còn tiền invoice 1.850.000 ¥'),
      );
      expect(
        nextStep(lot(due: 1850000), canPay: false).text,
        'Chờ trả tiền hàng',
      );
    });

    test('còn khoản thuế phí dự kiến, rồi chờ nhận hàng', () {
      expect(
        nextStep(lot(planned: 3), canPay: true).text,
        'Còn 3 khoản thuế phí',
      );
      expect(nextStep(lot(), canPay: true).text, 'Chờ nhận hàng');
    });
  });

  group('gom cây', () {
    test('gom theo hãng + model, giữ thứ tự gặp đầu', () {
      final groups = groupByModel([
        unit('a', model: 'EL900'),
        unit('b', model: 'ELB01'),
        unit('c', model: 'EL900', sale: UnitSale.reserved),
      ]);
      expect(groups.map((g) => g.key), ['YAMAHA EL900', 'YAMAHA ELB01']);
      expect(groups.first.items.map((u) => u.id), ['a', 'c']);
      expect(groups.first.withCustomer, 1);
    });

    test('danh mục model gợi ý lấy loại + giá của cây đầu có giá', () {
      final cat = modelCatalog([
        unit('a', model: 'U3H', category: 'Piano Upright cũ'),
        unit('b', model: 'U3H', list: 35500000, yen: 135000),
        unit('c', maker: 'KAWAI', model: 'CA48A'),
      ]);
      expect(cat, hasLength(2));
      final u3h = cat.first;
      expect(u3h.category, 'Piano Upright cũ');
      expect(u3h.listPrice, 35500000);
      expect(u3h.yenPrice, 135000);
      expect(suggestModels(cat, 'kawai ca').single.model, 'CA48A');
      expect(suggestModels(cat, ''), isEmpty);
    });

    test('tạo đơn sau nhận hàng: gom theo khách, bỏ bán lẻ và cây thiếu', () {
      final units = [
        unit(
          'a',
          sale: UnitSale.reserved,
          customerId: 'c1',
          customerName: 'Long',
          reserved: 12000000,
        ),
        unit(
          'b',
          sale: UnitSale.reserved,
          customerId: 'c1',
          customerName: 'Long',
          list: 5500000,
        ),
        unit(
          'c',
          sale: UnitSale.reserved,
          customerId: 'c2',
          customerName: 'Ngân',
          list: 1,
        ),
        unit('d', sale: UnitSale.reserved, retail: true),
        unit('e'),
      ];
      final groups = groupReservedByCustomer(units, {
        'c': ReceiveResult.missing,
      });
      expect(groups, hasLength(1));
      expect(groups.single.customerName, 'Long');
      expect(groups.single.units.map((u) => u.id), ['a', 'b']);
      expect(groups.single.total, 17500000);
    });
  });

  group('map JSON', () {
    test('cây: đủ khoá presenter, kể cả trường tiền khi có quyền', () {
      final u = InventoryUnit.fromJson({
        'id': 'u1',
        'lot_id': 'l1',
        'lot_code': 'Ep 64',
        'line_no': 14,
        'category': 'Electone',
        'maker': 'YAMAHA',
        'model': 'ELS01C',
        'serial': 'JAKNO2455',
        'color': 'SLV',
        'size': null,
        'list_price': 19000000,
        'place': 'in_stock',
        'condition': 'refurbishing',
        'sale': 'reserved',
        'retail_hold': false,
        'customer_id': 'c1',
        'customer_name': 'Chị Ngân',
        'reserved_price': 18500000,
        'deposit': 2000000,
        'reserved_at': '2026-11-09T10:00:00+07:00',
        'order_id': null,
        'received_at': '2026-11-01',
        'note': 'ghi chú',
        'yen_price': 60000,
        'cost_vnd': 11131571,
      });
      expect(u.lotCode, 'Ep 64');
      expect(u.lineNo, 14);
      expect(u.place, UnitPlace.inStock);
      expect(u.condition, UnitCondition.refurbishing);
      expect(u.sale, UnitSale.reserved);
      expect(u.customerName, 'Chị Ngân');
      expect(u.reservedPrice, 18500000);
      expect(u.deposit, 2000000);
      expect(u.receivedAt, '2026-11-01');
      expect(u.note, 'ghi chú');
      expect(u.yenPrice, 60000);
      expect(u.costVnd, 11131571);
      expect(u.suggestedPrice, 18500000);
      expect(u.hasCustomer, isTrue);
    });

    test(
      'cây không quyền giá: thiếu khoá tiền → null, tình trạng null = Chưa kiểm',
      () {
        final u = InventoryUnit.fromJson({
          'id': 'u',
          'maker': 'CASIO',
          'model': 'PX110',
        });
        expect(u.yenPrice, isNull);
        expect(u.costVnd, isNull);
        expect(u.condition, isNull);
        expect(UnitCondition.labelOf(u.condition), 'Chưa kiểm');
        expect(u.place, UnitPlace.incoming);
        expect(u.sale, UnitSale.available);
      },
    );

    test('lô chi tiết: tiền, khoản trả, nhật ký tỷ lệ', () {
      final l = Lot.fromJson({
        'id': 'l1',
        'code': 'Ep 64',
        'supplier_id': 's1',
        'supplier_name': 'Epco',
        'status': 'in_transit',
        'eta': '2026-11-20',
        'units': 120,
        'reserved': 18,
        'sold': 2,
        'in_stock': 0,
        'cost_state': 'provisional',
        'planned_count': 6,
        'yen_total': 5150000,
        'rate_applied': 200,
        'rate_manual': true,
        'rate_final': null,
        'rate_estimate': 180.36,
        'cost_total': 1030000000,
        'invoice_jpy': 1850000,
        'paid_vnd': 548250000,
        'planned_vnd': 73500000,
        'paid_jpy': 3300000,
        'due_jpy': 1850000,
        'last_fx': 166,
        'costs': [
          {
            'id': 'c1',
            'lot_id': 'l1',
            'kind': 'goods_invoice',
            'label': '',
            'amount_jpy': 1000000,
            'amount_vnd': 166000000,
            'fx': 166,
            'status': 'paid',
            'paid_at': '2026-10-01',
            'money_account_id': 'acb',
          },
          {
            'id': 'c5',
            'kind': 'import_tax',
            'amount_vnd': 35000000,
            'status': 'planned',
          },
        ],
        'rate_logs': [
          {
            'at': '2026-11-01T00:00:00Z',
            'reason': 'auto_final',
            'from': 200,
            'to': 185.53,
            'units': 120,
            'delta_vnd': -1000,
          },
        ],
      });
      expect(l.status, LotStatus.inTransit);
      expect(l.title, 'Ep 64 · Epco');
      expect(l.withCustomer, 20);
      expect(l.costFinal, isFalse);
      expect(l.rateManual, isTrue);
      expect(l.rateEstimate, 180.36);
      expect(l.dueJpy, 1850000);
      expect(l.lastFx, 166);
      expect(l.costs, hasLength(2));
      expect(l.costs!.first.kind, CostKind.goodsInvoice);
      expect(l.costs!.first.isGoods, isTrue);
      expect(l.costs!.first.title, 'Tiền hàng theo invoice');
      expect(l.costs!.first.moneyAccountId, 'acb');
      expect(l.costs!.last.status, CostStatus.planned);
      expect(l.rateLogs!.single.reasonLabel, 'Tự chốt giá vốn');
      expect(l.rateLogs!.single.to, 185.53);
    });

    test('lô không quyền tiền: không có khoản trả (null, không phải rỗng)', () {
      final l = Lot.fromJson({'id': 'l', 'code': 'Hmn12', 'status': 'ordered'});
      expect(l.costs, isNull);
      expect(l.rateApplied, isNull);
      expect(l.status, LotStatus.ordered);
    });

    test('body thêm cây: nhiều cây giống nhau không gửi serial', () {
      expect(
        const NewUnitInput(
          maker: ' yamaha ',
          model: 'U3H ',
          serial: '123',
          qty: 3,
          yenPrice: 135000,
          listPrice: 35500000,
          color: '',
        ).toPayload(),
        {
          'maker': 'yamaha',
          'model': 'U3H',
          'yen_price': 135000,
          'list_price': 35500000,
          'qty': 3,
        },
      );
      expect(
        const NewUnitInput(maker: 'Y', model: 'M', serial: 'S1').toPayload(),
        containsPair('serial', 'S1'),
      );
    });

    test('body khoản trả: thuế phí không gửi ¥, dự kiến không gửi ngày', () {
      final fee = const CostInput(
        kind: CostKind.importTax,
        status: CostStatus.planned,
        amountJpy: 999,
        amountVnd: 35000000,
        paidAt: '2026-11-09',
      ).toPayload();
      expect(fee['kind'], 'import_tax');
      expect(fee['amount_jpy'], isNull);
      expect(fee['paid_at'], isNull);
      expect(fee['amount_vnd'], 35000000);
      final goods = const CostInput(
        kind: CostKind.goodsOutside,
        status: CostStatus.paid,
        amountJpy: 1000000,
        amountVnd: 166000000,
        paidAt: '2026-11-09',
        moneyAccountId: 'acb',
      ).toPayload();
      expect(goods['amount_jpy'], 1000000);
      expect(goods['paid_at'], '2026-11-09');
      expect(goods['money_account_id'], 'acb');
    });
  });

  group('quyền Kho', () {
    InventoryPerms perms(Set<String> slugs, {bool capable = true}) =>
        InventoryPerms.from(capable: capable, policy: AccessPolicy(slugs));

    test('thiếu capability: mọi quyền false dù có slug', () {
      final p = perms({
        'inventory.read',
        'inventory.write',
        'inventory.reserve',
      }, capable: false);
      expect(p.read || p.write || p.reserve, isFalse);
    });

    test('không có read thì quyền khác vô nghĩa', () {
      final p = perms({'inventory.write', 'inventory.cost'});
      expect(p.read, isFalse);
      expect(p.write, isFalse);
      expect(p.cost, isFalse);
    });

    test('tạo đơn cần cả giữ hàng lẫn orders.write', () {
      expect(perms({'inventory.read', 'inventory.reserve'}).sell, isFalse);
      final p = perms({'inventory.read', 'inventory.reserve', 'orders.write'});
      expect(p.sell, isTrue);
      expect(p.canSellOrReserve, isTrue);
      expect(perms({'inventory.read'}).canSellOrReserve, isFalse);
    });
  });
}
