import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/notification_banner_overlay.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

void main() {
  testWidgets('NotificationBannerOverlay displays notification and dismisses on tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(392, 800));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NotificationBannerOverlay(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Exit Resonance'), findsNothing);

    // Trigger notification
    container.read(notificationProvider.notifier).showNotification(
      'Exit Resonance',
      'Press back again to exit Resonance',
      silentOsNotification: true,
    );

    await tester.pumpAndSettle();

    // Verify banner content is visible
    expect(find.text('Exit Resonance'), findsOneWidget);
    expect(find.text('Press back again to exit Resonance'), findsOneWidget);

    // Tap dismiss icon
    final dismissButton = find.byType(ReusableHoverIconButton);
    expect(dismissButton, findsOneWidget);
    await tester.tap(dismissButton);
    await tester.pumpAndSettle();

    // Verify dismissed
    expect(find.text('Exit Resonance'), findsNothing);
  });
}
