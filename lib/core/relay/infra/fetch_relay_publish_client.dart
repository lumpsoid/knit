import 'dart:convert';
import 'dart:typed_data';

import 'package:fetch_dart/fetch_dart.dart';
import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_failure.dart';
import 'package:knit/core/relay/domain/relay_publish_client.dart';
import 'package:result_dart/result_dart.dart';

/// [RelayPublishClient] over `package:fetch_dart` — the one place the relay HTTP
/// dependency lives. Every request is built with an absolute URL and sent
/// through [FetchClient.send] (which does not re-resolve against a base URL), so
/// the caller fully controls addressing; fetch_dart throws on a non-2xx status,
/// which we catch and fold into a [RelayFailure].
class FetchRelayPublishClient implements RelayPublishClient {
  FetchRelayPublishClient({required Uri baseUrl, FetchClient? client})
    : _base = _trimSlash(baseUrl.toString()),
      _client = client ?? FetchClient(FetchClientConfig());

  final String _base;
  final FetchClient _client;

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  String _url(String path) => '$_base$path';

  @override
  Future<Result<RelayTopic, RelayFailure>> createTopic(
    String ownerPubkey,
  ) async {
    final req = RequestBuilder().post(_url('/v1/topics')).jsonBody({
      'owner_pubkey': ownerPubkey,
    }).build();

    final res = await _run(() => _client.send<dynamic>(req));
    if (res.isFailure) return Failure(res.error!);

    final body = _json(res.getOrThrow());
    final topic = body?['topic'];
    final token = body?['token'];
    if (topic is! String || token is! String) {
      return const Failure(
        RelayResponseFailure(
          statusCode: 201,
          error: 'malformed create-topic response',
        ),
      );
    }
    return Ok(RelayTopic(topicId: topic, writeToken: token));
  }

  @override
  Future<Result<void, RelayFailure>> putBlob({
    required String topic,
    required String writeToken,
    required String hash,
    required String mime,
    required Uint8List bytes,
  }) async {
    final req = RequestBuilder()
        .put(_url('/v1/topics/$topic/blobs/$hash'))
        .header('authorization', 'Bearer $writeToken')
        .header('content-type', mime)
        .body(StreamBody(Stream.value(bytes)))
        .build();

    final res = await _run(() => _client.send<dynamic>(req));
    return res.isFailure ? Failure(res.error!) : const Ok(null);
  }

  @override
  Future<Result<PublishedRef, RelayFailure>> putPublication({
    required String topic,
    required String writeToken,
    required PublishVisibility visibility,
    String? title,
    required PublicationSnapshot snapshot,
  }) async {
    final req = RequestBuilder()
        .put(_url('/v1/topics/$topic/publication'))
        .header('authorization', 'Bearer $writeToken')
        .jsonBody({
          'visibility': visibility.tag,
          'title': ?title,
          'snapshot': snapshot.toJson(),
        })
        .build();

    final res = await _run(() => _client.send<dynamic>(req));
    if (res.isFailure) return Failure(res.error!);

    final ref = _parseRef(_json(res.getOrThrow()));
    return ref == null
        ? const Failure(
            RelayResponseFailure(
              statusCode: 200,
              error: 'malformed publication response',
            ),
          )
        : Ok(ref);
  }

  @override
  Future<Result<PublishedRef?, RelayFailure>> getPublication({
    required String topic,
    required String writeToken,
  }) async {
    final req = RequestBuilder()
        .get(_url('/v1/topics/$topic/publication'))
        .header('authorization', 'Bearer $writeToken')
        .build();

    try {
      final res = await _client.send<dynamic>(req);
      // A 404 here means "never published", not an error.
      if (!res.isSuccess) return const Ok(null);
      return Ok(_parseRef(_json(res)));
    } on HttpError catch (e) {
      if (e.statusCode == 404) return const Ok(null);
      return Failure(
        RelayResponseFailure(
          statusCode: e.statusCode,
          code: _errorCode(e.response),
          error: e.message,
        ),
      );
    } on FetchError catch (e, st) {
      return Failure(RelayNetworkFailure(e, st));
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }

  @override
  Future<Result<void, RelayFailure>> deletePublication({
    required String topic,
    required String writeToken,
  }) async {
    final req = RequestBuilder()
        .delete(_url('/v1/topics/$topic/publication'))
        .header('authorization', 'Bearer $writeToken')
        .build();

    final res = await _run(() => _client.send<dynamic>(req));
    return res.isFailure ? Failure(res.error!) : const Ok(null);
  }

  // ── Transport plumbing ──────────────────────────────────────────────────────

  Future<Result<FetchResponse<dynamic>, RelayFailure>> _run(
    Future<FetchResponse<dynamic>> Function() send,
  ) async {
    try {
      final res = await send();
      if (res.isSuccess) return Ok(res);
      return Failure(
        RelayResponseFailure(
          statusCode: res.statusCode,
          code: _errorCode(res),
          error: 'HTTP ${res.statusCode}',
        ),
      );
    } on HttpError catch (e) {
      return Failure(
        RelayResponseFailure(
          statusCode: e.statusCode,
          code: _errorCode(e.response),
          error: e.message,
        ),
      );
    } on FetchError catch (e, st) {
      return Failure(RelayNetworkFailure(e, st));
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }

  /// Decode the response body as a JSON object. We parse the raw bytes directly
  /// (rather than trust the adapter's default `data`) so JSON is available
  /// whether or not a decoder was attached.
  Map<String, dynamic>? _json(FetchResponse<dynamic> res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.rawBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _errorCode(FetchResponse<dynamic> res) {
    final code = _json(res)?['error'];
    return code is String ? code : null;
  }

  PublishedRef? _parseRef(Map<String, dynamic>? body) {
    if (body == null) return null;
    final slug = body['slug'];
    final url = body['url'];
    if (slug is! String || url is! String) return null;
    return PublishedRef(
      slug: slug,
      url: url,
      visibility: PublishVisibility.fromTag(body['visibility'] as String?),
      revoked: body['revoked'] == true,
      publishedAt: (body['published_at'] as num?)?.toInt() ?? 0,
    );
  }
}
