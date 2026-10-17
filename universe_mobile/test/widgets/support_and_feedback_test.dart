import 'package:flutter_test/flutter_test.dart';
import 'package:universe_mobile/config/support_config.dart';
import 'package:universe_mobile/screens/feedback_screen.dart';

void main() {
  group('SupportConfig', () {
    test('email link is a mailto with an encoded subject', () {
      final uri = SupportConfig.emailUri(subject: 'Need help');
      expect(uri.scheme, 'mailto');
      expect(uri.toString(), contains('subject=Need%20help'));
      expect(uri.toString(), isNot(contains('+')));
    });

    test('whatsapp hidden while the number is empty', () {
      expect(SupportConfig.hasWhatsapp, SupportConfig.whatsapp.trim().isNotEmpty);
    });
  });

  group('feedbackErrorMessage', () {
    test('offline keeps the message and says so', () {
      expect(feedbackErrorMessage({'networkError': true}), contains('No connection'));
    });
    test('429 asks to wait', () {
      expect(feedbackErrorMessage({'statusCode': 429}), contains('too fast'));
      expect(feedbackErrorMessage({'rateLimited': true}), contains('too fast'));
    });
    test('uses the server error when there is one', () {
      expect(feedbackErrorMessage({'error': 'Message is too short'}), 'Message is too short');
    });
    test('generic fallback', () {
      expect(feedbackErrorMessage({}), contains('try again'));
      expect(feedbackErrorMessage(null), contains('try again'));
    });
  });
}
