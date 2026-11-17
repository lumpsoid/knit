/// The version line on About: `0.1.0 (2391c1d)`. [commit] is the build's git
/// hash, passed in by the build scripts as `--dart-define=GIT_COMMIT=<hash>`
/// ([buildCommit]); a build without it shows the bare version.
class AppVersion {
  const AppVersion(this.version, {this.commit = ''});

  /// The hash this binary was built from, or empty.
  static const String buildCommit = String.fromEnvironment('GIT_COMMIT');

  /// Shown hash length: 4 collides, 7 is git's own short default.
  static const int commitLength = 7;

  final String version;
  final String commit;

  String get label {
    final hash = commit.trim();
    if (hash.isEmpty) return version;
    final short = hash.length > commitLength
        ? hash.substring(0, commitLength)
        : hash;
    return '$version ($short)';
  }
}
