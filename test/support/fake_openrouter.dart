import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned reply from the fake.
class FakeReply {
  const FakeReply.ok(this.body, {this.delay = Duration.zero}) : status = 200;
  const FakeReply.status(this.status, {this.delay = Duration.zero})
      : body = '{}';

  /// A reply that takes longer than the client is willing to wait.
  ///
  /// The only way to exercise the chain deadline, which is the thing that
  /// stands between a slow free model and a four-minute spinner.
  const FakeReply.slow(this.delay)
      : status = 200,
        body = '{}';

  final int status;
  final String body;

  /// How long the "network" takes before answering.
  final Duration delay;
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

  /// Every URL asked for, in order. The client talks to two endpoints now.
  final List<String> paths = [];
  final List<Map<String, List<String>>> headers = [];

  int get callCount => requests.length;

  /// The models asked, in the order they were asked.
  ///
  /// Requests with no model are skipped rather than crashing: not every call
  /// the client makes is an inference call.
  List<String> get modelsTried =>
      [for (final r in requests) ?(r['model'] as String?)];

  /// Every request body as one JSON string, for scanning.
  String get wire => jsonEncode(requests);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // At the adapter layer Dio has not serialised the body yet, so `data` is
    // still the map the client built. Handle every shape so the fake does not
    // depend on where in the pipeline it is installed — including *no* body,
    // which is what the key-standing GET sends. Casting that to a Map threw a
    // TypeError the client swallowed, so the call looked unanswerable rather
    // than unasked.
    final data = options.data;
    requests.add(switch (data) {
      null => const <String, dynamic>{},
      final String body => jsonDecode(body) as Map<String, dynamic>,
      final Map<Object?, Object?> body => Map<String, dynamic>.from(body),
      _ => <String, dynamic>{'body': data.toString()},
    });
    paths.add(options.uri.toString());
    headers.add({
      for (final entry in options.headers.entries)
        entry.key: [entry.value.toString()],
    });

    if (requests.length > replies.length) {
      throw StateError('unexpected call ${requests.length}');
    }

    final reply = replies[requests.length - 1];
    if (reply.delay > Duration.zero) await Future<void>.delayed(reply.delay);
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
