/// Carries username + bio forward from the Username step through Photo,
/// Bio, University, Faculty, and Department — all the way to the Level
/// step, where PATCH /profile/complete-setup finally saves username +
/// bio + level together in one write. This mirrors the backend's own
/// design intent: a saved username with no level (someone abandoning
/// partway through) should never happen.
class ProfileSetupData {
  final String username;
  final String bio;

  const ProfileSetupData({this.username = '', this.bio = ''});

  ProfileSetupData copyWith({String? bio}) {
    return ProfileSetupData(username: username, bio: bio ?? this.bio);
  }
}
