import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Menguji parsing model keuangan: tahan nilai null, string angka, dan
/// field yang belum dikirim backend.

void main() {
  group('FixedCost.fromJson', () {
    test('membaca field lengkap', () {
      final c = FixedCost.fromJson({
        'id': 'a1', 'name': 'Sewa', 'amount': 3000000,
        'category': 'tempat', 'due_day': 5, 'is_active': true,
      });
      expect(c.id, 'a1');
      expect(c.name, 'Sewa');
      expect(c.amount, 3000000);
      expect(c.dueDay, 5);
      expect(c.isActive, isTrue);
    });

    test('nilai null tidak bikin crash', () {
      final c = FixedCost.fromJson({'id': 'a1', 'name': 'X', 'amount': null});
      expect(c.amount, 0);
      expect(c.category, '');
      expect(c.dueDay, isNull);
      expect(c.isActive, isTrue); // default aktif
    });

    test('amount berupa string angka tetap terbaca', () {
      expect(FixedCost.fromJson({'id': 'a', 'name': 'X', 'amount': '250000'}).amount, 250000);
    });
  });

  group('ProfitLoss.fromJson', () {
    test('membaca ringkasan laba rugi', () {
      final p = ProfitLoss.fromJson({
        'month': '2026-08',
        'revenue': 36000000, 'cogs': 14902271,
        'grossProfit': 21097729, 'grossMarginPct': 59,
        'fixedCosts': 8000000, 'variableExpenses': 500000,
        'paymentFees': 100800, 'netProfit': 12496929, 'netMarginPct': 35,
        'fixed_cost_items': [
          {'id': 'f1', 'name': 'Sewa', 'amount': 8000000, 'is_active': true},
        ],
      });
      expect(p.month, '2026-08');
      expect(p.revenue, 36000000);
      expect(p.netProfit, 12496929);
      expect(p.fixedCostItems.length, 1);
      expect(p.fixedCostItems.first.name, 'Sewa');
    });

    test('laba bersih negatif terbaca apa adanya', () {
      final p = ProfitLoss.fromJson({'month': '2026-01', 'netProfit': -400000, 'netMarginPct': -40});
      expect(p.netProfit, -400000);
      expect(p.netMarginPct, -40);
    });

    test('respons kosong menghasilkan nol, bukan exception', () {
      final p = ProfitLoss.fromJson(const {});
      expect(p.revenue, 0);
      expect(p.netProfit, 0);
      expect(p.fixedCostItems, isEmpty);
    });

    test('variable_expenses_unavailable: true terbaca sebagai flag aktif', () {
      final p = ProfitLoss.fromJson({
        'month': '2026-08',
        'variableExpenses': 0,
        'variable_expenses_unavailable': true,
      });
      expect(p.variableExpensesUnavailable, isTrue);
    });

    test('variable_expenses_unavailable tidak dikirim → default false', () {
      final p = ProfitLoss.fromJson({'month': '2026-08', 'variableExpenses': 500000});
      expect(p.variableExpensesUnavailable, isFalse);
    });
  });
}
