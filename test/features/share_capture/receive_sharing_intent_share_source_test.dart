import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/infra/receive_sharing_intent_share_source.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('share_src'));
  tearDown(() => dir.delete(recursive: true));

  test(
    'maps text, existing files and their mime; drops empty entries',
    () async {
      final photo = File('${dir.path}/IMG_1.jpg')..writeAsBytesSync([1]);
      final doc = File('${dir.path}/notes.pdf')..writeAsBytesSync([2]);
      final textFile = File('${dir.path}/todo.txt')..writeAsStringSync('x');
      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(
            path: 'hello',
            type: SharedMediaType.text,
            mimeType: 'text/plain',
          ),
          SharedMediaFile(
            path: photo.path,
            type: SharedMediaType.image,
            mimeType: 'image/jpeg',
          ),
          // No declared mime → judged by the extension.
          SharedMediaFile(path: doc.path, type: SharedMediaType.file),
          // A shared .txt *file* arrives typed as text, but is a real file.
          SharedMediaFile(
            path: textFile.path,
            type: SharedMediaType.text,
            mimeType: 'text/plain',
          ),
          SharedMediaFile(path: '', type: SharedMediaType.text),
        ],
        mediaStream: const Stream.empty(),
      );

      final items = await ReceiveSharingIntentShareSource().initial();

      expect(items, hasLength(4));
      expect((items[0] as SharedText).text, 'hello');
      final image = items[1] as SharedFile;
      expect(image.mime, 'image/jpeg');
      expect(image.name, 'IMG_1.jpg');
      expect((items[2] as SharedFile).mime, 'application/pdf');
      expect((items[3] as SharedFile).name, 'todo.txt');
    },
  );

  test('a path-like text that is not a file stays text', () async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(path: '/not/a/file', type: SharedMediaType.text),
      ],
      mediaStream: const Stream.empty(),
    );
    final items = await ReceiveSharingIntentShareSource().initial();
    expect((items.single as SharedText).text, '/not/a/file');
  });
}
