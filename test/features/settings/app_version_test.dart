import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/settings/domain/app_version.dart';

void main() {
  group('AppVersion.label', () {
    test('appends the short commit hash', () {
      expect(
        const AppVersion('0.1.0', commit: '2391c1d').label,
        '0.1.0 (2391c1d)',
      );
    });

    test('cuts a full hash to 7 characters', () {
      expect(
        const AppVersion(
          '0.1.0',
          commit: '2391c1d8f00e4b6c9a1d2e3f4a5b6c7d8e9f0a1b',
        ).label,
        '0.1.0 (2391c1d)',
      );
    });

    test('is the bare version without a commit', () {
      expect(const AppVersion('0.1.0').label, '0.1.0');
      expect(const AppVersion('0.1.0', commit: '  ').label, '0.1.0');
    });
  });
}
