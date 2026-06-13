import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/attachments.dart';

void main() {
  test('sha256Hex is deterministic for the same bytes', () async {
    final bytes = Uint8List.fromList([10, 20, 30, 40]);
    expect(await sha256Hex(bytes), await sha256Hex(bytes));
  });

  test('different bytes hash differently', () async {
    expect(
      await sha256Hex([1, 2, 3]),
      isNot(await sha256Hex([1, 2, 4])),
    );
  });

  test('matches the known SHA-256 empty-input vector', () async {
    expect(
      await sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });
}
