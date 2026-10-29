import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A dio [HttpClientAdapter] that answers every request with [respond], so
/// `ApiClient` can be tested without a server.
///
/// [requests] keeps what was sent, to check headers and paths.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.respond);

  /// Builds the answer to a request; throw a [DioException] to simulate a
  /// network failure.
  Future<ResponseBody> Function(RequestOptions options) respond;

  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response with [status], as the API would send it.
ResponseBody jsonResponse(
  int status,
  Object body, {
  String contentType = 'application/json',
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [contentType],
  },
);

/// An `application/problem+json` error with the API's [code].
ResponseBody problemResponse(int status, String code) => jsonResponse(status, {
  'status': status,
  'code': code,
  'title': code,
}, contentType: 'application/problem+json');
