import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned reply from the fake.
class FakeReply {
  const FakeReply.ok(this.body) : status = 200;
  const FakeReply.status(this.status) : body = '{}';

  final int status;
  final String body;
}

/// Stands in for the network, for every test that touches OpenRouter.
///
/// No test may reach the real thing. A real call would need a real key, and a
/// key must never be in the repo (CLAUDE.md §2); it would also spend one of
/// fifty daily requests per run, which is not a budget a test suite can draw
/// on.
///
/// Shared rather than copied into each suite: the fake is the only description
/// of what the wire looks like, and two of them would drift apart.
class FakeOpenRouterAdapter implements HttpClientAdapter {
  FakeOpenRouterAdapter(this.replies);

  /// One reply per request, in order. Runs out deliberately rather than
  /// repeating, so a test that makes an unexpected extra call fails loudly.
  final List<FakeReply> replies;

  final List<Map<String, dynamic>> requests = [];
  final List<Map<String, List<String>>> headers = [];

  int get callCount => requests.length;

  /// The models asked, in the order they were asked.
  List<String> get modelsTried =>
      requests.map((r) => r['model'] as String).toList();

  /// Every request body as one JSON string, for scanning.
  String get wire => jsonEncode(requests);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // At the adapter layer Dio has not serialised the body yet, so `data` is
    // still the map the client built. Handle both shapes so the fake does not
    // depend on where in the pipeline it is installed.
    final data = options.data;
    requests.add(
      data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : Map<String, dynamic>.from(data as Map),
    );
    headers.add({
      for (final entry in options.headers.entries)
        entry.key: [entry.value.toString()],
    });

    if (requests.length > replies.length) {
      throw StateError('unexpected call ${requests.length}');
    }

    final reply = replies[requests.length - 1];
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
