library eventsource;

export "src/event.dart";

import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart" show MediaType;

import "src/event.dart";
import "src/decoder.dart";

enum EventSourceReadyState {
  connecting,
  open,
  closed,
}

Encoding encodingForCharset(String? charset, [Encoding fallback = latin1]) {
  if (charset == null) return fallback;
  return Encoding.getByName(charset) ?? fallback;
}

class EventSourceSubscriptionException extends Event implements Exception {
  int statusCode;
  String message;

  @override
  String get data => "$statusCode: $message";

  EventSourceSubscriptionException(this.statusCode, this.message)
      : super(event: "error");
}

/// An EventSource client that exposes a [Stream] of [Event]s.
class EventSource extends Stream<Event> {
  // interface attributes

  final Uri url;
  final Map<String, String>? headers;

  EventSourceReadyState get readyState => _readyState;

  Stream<Event> get onOpen => where((e) => e.event == "open");
  Stream<Event> get onMessage => where((e) => e.event == "message");
  Stream<Event> get onError => where((e) => e.event == "error");

  // internal attributes

  final StreamController<Event> _streamController =
      StreamController<Event>.broadcast();

  EventSourceReadyState _readyState = EventSourceReadyState.closed;

  http.Client client;
  Duration _retryDelay = const Duration(milliseconds: 3000);
  String? _lastEventId;
  late EventSourceDecoder _decoder;
  final String _body;
  final String _method;

  /// Create a new EventSource by connecting to the specified url.
  static Future<EventSource> connect(url,
      {http.Client? client,
      String? lastEventId,
      Map<String, String>? headers,
      String? body,
      String? method}) async {
    // parameter initialization
    url = url is Uri ? url : Uri.parse(url);
    client = client ?? http.Client();
    body = body ?? "";
    method = method ?? "GET";
    EventSource es =
        EventSource._internal(url, client, lastEventId, headers, body, method);
    await es._start();
    return es;
  }

  EventSource._internal(this.url, this.client, this._lastEventId, this.headers,
      this._body, this._method) {
    _decoder = EventSourceDecoder(retryIndicator: _updateRetryDelay);
  }

  // proxy the listen call to the controller's listen call
  @override
  StreamSubscription<Event> listen(void Function(Event event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  /// Attempt to start a new connection.
  Future _start() async {
    _readyState = EventSourceReadyState.connecting;
    var request = http.Request(_method, url);
    request.headers["Cache-Control"] = "no-cache";
    request.headers["Accept"] = "text/event-stream";
    if (_lastEventId?.isNotEmpty == true) {
      request.headers["Last-Event-ID"] = _lastEventId!;
    }
    headers?.forEach((k, v) {
      request.headers[k] = v;
    });
    request.body = _body;

    var response = await client.send(request);
    if (response.statusCode != 200) {
      // server returned an error
      var bodyBytes = await response.stream.toBytes();
      String body = _encodingForHeaders(response.headers).decode(bodyBytes);
      throw EventSourceSubscriptionException(response.statusCode, body);
    }
    _readyState = EventSourceReadyState.open;
    // start streaming the data
    response.stream.transform(_decoder).listen((Event event) {
      _streamController.add(event);
      _lastEventId = event.id;
    },
        cancelOnError: true,
        onError: _retry,
        onDone: () => _readyState = EventSourceReadyState.closed);
  }

  /// Retries until a new connection is established. Uses exponential backoff.
  Future _retry(dynamic e) async {
    _readyState = EventSourceReadyState.connecting;
    // try reopening with exponential backoff
    Duration backoff = _retryDelay;
    while (true) {
      await Future.delayed(backoff);
      try {
        await _start();
        break;
      } catch (error) {
        _streamController.addError(error);
        backoff *= 2;
      }
    }
  }

  void _updateRetryDelay(Duration retry) {
    _retryDelay = retry;
  }
}

/// Returns the encoding to use for a response with the given headers. This
/// defaults to [LATIN1] if the headers don't specify a charset or
/// if that charset is unknown.
Encoding _encodingForHeaders(Map<String, String> headers) =>
    encodingForCharset(_contentTypeForHeaders(headers).parameters['charset']);

/// Returns the [MediaType] object for the given headers's content-type.
///
/// Defaults to `application/octet-stream`.
MediaType _contentTypeForHeaders(Map<String, String> headers) {
  var contentType = headers['content-type'];
  if (contentType != null) return MediaType.parse(contentType);
  return MediaType("application", "octet-stream");
}
