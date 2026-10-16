import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection_details/domain/collection_details.dart';
import 'package:knit/features/collection_details/domain/collection_details_failure.dart';
import 'package:knit/features/collection_details/domain/collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:result_dart/result_dart.dart';

class _FakeWrite implements CollectionDetailsWriteRepository {
  bool fail = false;
  final calls = <String>[];

  Future<Result<String, CollectionDetailsFailure>> _result(
    String call,
    String id,
  ) async {
    calls.add(call);
    return fail
        ? Failure(CollectionDetailsWriteFailure(StateError('boom')))
        : Ok(id);
  }

  @override
  Future<Result<String, CollectionDetailsFailure>> editDetails({
    required String collectionId,
    required String title,
    String? description,
  }) => _result('editDetails', collectionId);

  @override
  Future<Result<String, CollectionDetailsFailure>> setCover({
    required String collectionId,
    required String attachmentId,
  }) => _result('setCover:$attachmentId', collectionId);

  @override
  Future<Result<String, CollectionDetailsFailure>> removeCover({
    required String collectionId,
  }) => _result('removeCover', collectionId);
}

class _FakeAttachmentWrite implements AttachmentWriteRepository {
  final deleted = <String>[];

  @override
  Future<Result<String, AttachmentFailure>> delete(String attachmentId) async {
    deleted.add(attachmentId);
    return Ok(attachmentId);
  }

  @override
  Future<Result<String, AttachmentFailure>> createFromPicked(
    PickedImage image,
  ) => throw UnimplementedError();

  @override
  Future<Result<String, AttachmentFailure>> createFromAudio(
    PickedAudio audio,
  ) => throw UnimplementedError();

  @override
  Future<Result<String, AttachmentFailure>> createFromFile(PickedFile file) =>
      throw UnimplementedError();
}

void main() {
  late _FakeWrite write;
  late _FakeAttachmentWrite attachments;
  late CollectionDetailsController controller;
  late int notifications;

  const espresso = CollectionDetails(
    collectionId: 'col-1',
    title: 'Espresso',
    description: 'notes',
    coverAttachmentId: 'att-1',
  );

  setUp(() {
    write = _FakeWrite();
    attachments = _FakeAttachmentWrite();
    controller = CollectionDetailsController(
      writeRepository: write,
      attachmentWriteRepository: attachments,
    );
    notifications = 0;
    controller.state.addListener(() => notifications++);
  });

  group('remember', () {
    test('records a header and notifies', () {
      controller.remember(espresso);
      expect(controller.state.of('col-1'), espresso);
      expect(notifications, 1);
    });

    test('an unchanged header does not notify again', () {
      controller.remember(espresso);
      controller.remember(espresso);
      expect(notifications, 1);
    });

    test('a batch replaces older copies with one notification', () {
      controller.remember(espresso);
      controller.rememberAll([
        espresso.copyWith(title: 'Ristretto'),
        const CollectionDetails(collectionId: 'col-2', title: 'Tea'),
      ]);
      expect(controller.state.of('col-1')!.title, 'Ristretto');
      expect(controller.state.of('col-2')!.title, 'Tea');
      expect(notifications, 2);
    });
  });

  group('saveDetails', () {
    test('a successful save updates the shared header', () async {
      controller.remember(espresso);
      final result = await controller.saveDetails(
        collectionId: 'col-1',
        title: 'Ristretto',
      );
      expect(result.isSuccess, isTrue);
      final header = controller.state.of('col-1')!;
      expect(header.title, 'Ristretto');
      expect(header.description, isNull);
      expect(header.coverAttachmentId, 'att-1');
    });

    test('a failed save leaves the header untouched', () async {
      controller.remember(espresso);
      write.fail = true;
      final result = await controller.saveDetails(
        collectionId: 'col-1',
        title: 'Ristretto',
      );
      expect(result.isFailure, isTrue);
      expect(controller.state.of('col-1'), espresso);
    });
  });

  group('cover', () {
    test(
      'setCover points the header at the new cover and GCs the old',
      () async {
        controller.remember(espresso);
        await controller.setCover(collectionId: 'col-1', attachmentId: 'att-2');
        expect(controller.state.of('col-1')!.coverAttachmentId, 'att-2');
        expect(attachments.deleted, ['att-1']);
      },
    );

    test('setCover with the same cover reclaims nothing', () async {
      controller.remember(espresso);
      await controller.setCover(collectionId: 'col-1', attachmentId: 'att-1');
      expect(attachments.deleted, isEmpty);
    });

    test('removeCover clears the header and GCs the image', () async {
      controller.remember(espresso);
      await controller.removeCover('col-1');
      expect(controller.state.of('col-1')!.hasCover, isFalse);
      expect(attachments.deleted, ['att-1']);
    });

    test('a failed cover write keeps the cover and reclaims nothing', () async {
      controller.remember(espresso);
      write.fail = true;
      await controller.removeCover('col-1');
      expect(controller.state.of('col-1')!.coverAttachmentId, 'att-1');
      expect(attachments.deleted, isEmpty);
    });
  });
}
