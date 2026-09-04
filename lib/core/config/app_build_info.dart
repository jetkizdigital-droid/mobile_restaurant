/// Release metadata shared by CMS, push registration and diagnostics.
///
/// Keep this in sync with pubspec.yaml. CI verifies the contract on every
/// release build so a version bump cannot silently drift.
abstract final class AppBuildInfo {
  static const String versionName = '1.0.0';
  static const String buildNumber = '1';
  static const String fullVersion = '$versionName+$buildNumber';
}
