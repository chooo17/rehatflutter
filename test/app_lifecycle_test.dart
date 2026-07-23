import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/app_lifecycle.dart';

void main() {
  late ProviderContainer container;

  Future<void> mount(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleWatcher(child: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('awalnya dianggap foreground', (tester) async {
    await mount(tester);
    expect(container.read(appForegroundProvider), isTrue);
  });

  testWidgets('paused → foreground jadi false', (tester) async {
    await mount(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(appForegroundProvider), isFalse);
  });

  testWidgets('resumed → foreground kembali true', (tester) async {
    await mount(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(container.read(appForegroundProvider), isTrue);
  });
}
