import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/auth/presentation/widgets/auth_brand.dart';
import 'package:rehat_app/features/auth/presentation/widgets/auth_split_layout.dart';

const _logo = AssetImage(AuthBrandAssets.logoStiker);
const _kura = AssetImage(AuthBrandAssets.kuraKura);
const _lockup = AssetImage(AuthBrandAssets.lockupHorizontal);

void _view(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: AuthSplitLayout(child: Text('FORM'))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('layar lebar (>= 900)', () {
    testWidgets('AC-001/002: panel brand dgn logo, kura-kura & tagline; tanpa header',
        (tester) async {
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.byType(AuthBrandPanel), findsOneWidget);
      expect(find.byType(AuthBrandHeader), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
      expect(find.image(_logo), findsOneWidget);
      expect(find.image(_kura), findsOneWidget);
      expect(find.text('You deserve a rest.'), findsOneWidget);
      expect(find.text('Let God work in mysterious ways.'), findsOneWidget);
    });

    testWidgets('AC-003: isi panel lama sudah hilang', (tester) async {
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.text('Kopi favoritmu, sekali ketuk.'), findsNothing);
      expect(find.text('9 stamp = 1 kopi gratis'), findsNothing);
      expect(find.text('Kumpulkan poin di setiap pesanan'), findsNothing);
    });

    testWidgets('AC-007: logo berlabel utk pembaca layar, ilustrasi dekoratif',
        (tester) async {
      final semantics = tester.ensureSemantics();
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.bySemanticsLabel('Rehat Coffeehouse'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('kura|lockup', caseSensitive: false)),
          findsNothing);
      semantics.dispose();
    });

    // Regresi: jendela pendek/sempit (tagline terbungkus 2 baris) membuat
    // kura-kura (dulu Positioned di Stack) menimpa tagline.
    for (final size in const [Size(900, 600), Size(1000, 560), Size(900, 800)]) {
      testWidgets('kura-kura tidak menimpa tagline di ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        _view(tester, size);
        await _pump(tester);

        final kura = find.image(_kura);
        if (kura.evaluate().isEmpty) return; // terlalu sempit → disembunyikan: OK
        final kuraRect = tester.getRect(kura);
        for (final line in [kRehatTagline.$1, kRehatTagline.$2]) {
          final textRect = tester.getRect(find.text(line));
          expect(kuraRect.overlaps(textRect), isFalse,
              reason: '"$line" $textRect tertimpa kura-kura $kuraRect');
        }
      });
    }

    testWidgets('kura-kura disembunyikan bila sisa ruang terlalu kecil',
        (tester) async {
      _view(tester, const Size(900, 420));
      await _pump(tester);

      expect(find.image(_kura), findsNothing);
      expect(find.text(kRehatTagline.$1), findsOneWidget);
    });
  });

  group('layar sempit (< 900)', () {
    testWidgets('AC-004: header brand dgn lockup & tagline; tanpa panel',
        (tester) async {
      _view(tester, const Size(400, 800));
      await _pump(tester);

      expect(find.byType(AuthBrandHeader), findsOneWidget);
      expect(find.byType(AuthBrandPanel), findsNothing);
      expect(find.image(_lockup), findsOneWidget);
      expect(find.text('You deserve a rest.'), findsOneWidget);
      expect(find.text('Let God work in mysterious ways.'), findsOneWidget);
      expect(find.text('FORM'), findsOneWidget);
    });

    testWidgets('AC-005: header sembunyi saat keyboard terbuka', (tester) async {
      _view(tester, const Size(400, 800), keyboard: 300);
      await _pump(tester);

      expect(find.image(_lockup), findsNothing);
      expect(find.text('You deserve a rest.'), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
    });

    testWidgets('AC-006: header sembunyi di layar pendek (< 560)', (tester) async {
      _view(tester, const Size(400, 500));
      await _pump(tester);

      expect(find.image(_lockup), findsNothing);
      expect(find.text('You deserve a rest.'), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
    });
  });
}
