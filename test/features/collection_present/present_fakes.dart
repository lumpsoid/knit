/// Fakes for the presentation's ports, shared by its controller and page tests.
library;

import 'dart:typed_data';

import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/audio_player_port.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/present_read_repository.dart';
import 'package:knit/features/collection_present/domain/screen_awake_port.dart';
import 'package:result_dart/result_dart.dart';

class FakePresentRead implements PresentReadRepository {
  FakePresentRead(this.result);
  final Result<PresentSource, PresentFailure> result;

  @override
  Future<Result<PresentSource, PresentFailure>> loadSource(
    String collectionId,
  ) async => result;
}

/// Serves every attachment and records which were read.
class FakeAttachments implements AttachmentReadRepository {
  final List<String> reads = [];

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(String id) async {
    reads.add(id);
    return Ok(AttachmentBytes(bytes: Uint8List(4), mime: 'image/png'));
  }
}

class SilentPlayer implements AudioPlayerPort {
  final List<String> calls = [];

  @override
  Stream<PlaybackProgress> get progress => const Stream.empty();
  @override
  Stream<PlaybackPhase> get phases => const Stream.empty();
  @override
  Future<void> play(Uint8List bytes, {required String mime}) async =>
      calls.add('play');
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async {}
}

class FakeLauncher implements LinkLauncher {
  bool succeeds = true;
  final List<String> opened = [];

  @override
  Future<Result<void, CollectionFailure>> open(String url) async {
    opened.add(url);
    return succeeds
        ? const Ok<void, CollectionFailure>(null)
        : const Failure(CollectionLinkOpenFailure('no handler'));
  }
}

class FakeAwake implements ScreenAwakePort {
  final List<bool> calls = [];

  @override
  Future<void> keepOn({required bool enabled}) async => calls.add(enabled);
}
