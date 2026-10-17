import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_mobile/widgets/welcome_checklist.dart';

void main() {
  group('ChecklistProgress.fromData', () {
    test('new account has nothing done', () {
      final p = ChecklistProgress.fromData(profile: {'bio': '', 'avatar_url': null});
      expect(p.done, 0);
      expect(p.allDone, false);
      expect(p.fraction, 0);
    });

    test('profile needs BOTH photo and bio', () {
      expect(
        ChecklistProgress.fromData(profile: {'avatar_url': 'x.png', 'bio': ''}).profileDone,
        false,
      );
      expect(
        ChecklistProgress.fromData(profile: {'avatar_url': '', 'bio': 'hi'}).profileDone,
        false,
      );
      expect(
        ChecklistProgress.fromData(profile: {'avatar_url': 'x.png', 'bio': 'hi'}).profileDone,
        true,
      );
    });

    test('verified only when is_verified is exactly true', () {
      expect(ChecklistProgress.fromData(profile: {'is_verified': true}).verified, true);
      expect(ChecklistProgress.fromData(profile: {'is_verified': 'true'}).verified, false);
      expect(ChecklistProgress.fromData(profile: {}).verified, false);
    });

    test('posts, conversations and explored tick their rows', () {
      final p = ChecklistProgress.fromData(
        profile: {},
        postCount: 2,
        conversationCount: 1,
        explored: true,
      );
      expect(p.posted, true);
      expect(p.messaged, true);
      expect(p.explored, true);
      expect(p.done, 3);
    });

    test('everything done', () {
      final p = ChecklistProgress.fromData(
        profile: {'avatar_url': 'a', 'bio': 'b', 'is_verified': true},
        postCount: 1,
        conversationCount: 1,
        explored: true,
      );
      expect(p.allDone, true);
      expect(p.fraction, 1);
    });

    test('null profile is safe', () {
      expect(ChecklistProgress.fromData().done, 0);
    });
  });

  group('ChecklistStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('dismiss is remembered per user', () async {
      expect(await ChecklistStore.isDismissed('u1'), false);
      await ChecklistStore.dismiss('u1');
      expect(await ChecklistStore.isDismissed('u1'), true);
      expect(await ChecklistStore.isDismissed('u2'), false);
    });

    test('explored flag is remembered per user', () async {
      expect(await ChecklistStore.isExplored('u1'), false);
      await ChecklistStore.markExplored('u1');
      expect(await ChecklistStore.isExplored('u1'), true);
      expect(await ChecklistStore.isExplored('u2'), false);
    });
  });
}
