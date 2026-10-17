import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_mobile/widgets/empty_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppEmptyState shows title, message and runs the action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing here',
          message: 'Be the first.',
          actionLabel: 'Create',
          onAction: () => tapped++,
        ),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Be the first.'), findsOneWidget);
    await tester.tap(find.text('Create'));
    expect(tapped, 1);
  });

  testWidgets('AppEmptyState without an action shows no button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppEmptyState(icon: Icons.school_outlined, title: 'T', message: 'M'),
      ),
    ));
    expect(find.byType(ElevatedButton), findsNothing);
  });

  group('loadErrorMessage', () {
    test('offline gets the connection message', () {
      expect(
        loadErrorMessage({'success': false, 'networkError': true}, 'fallback'),
        contains('internet'),
      );
    });
    test('rate limit gets the wait message', () {
      expect(
        loadErrorMessage({'success': false, 'rateLimited': true}, 'fallback'),
        contains('wait'),
      );
    });
    test('anything else falls back', () {
      expect(loadErrorMessage({'success': false}, 'fallback'), 'fallback');
      expect(loadErrorMessage(null, 'fallback'), 'fallback');
    });
  });
}
