library eventsource.io_server;

import "dart:io" as io;

import "package:sync/waitgroup.dart";

import "publisher.dart";
import "src/encoder.dart";

/// Create a handler to serve [io.HttpRequest] objects for the specified
/// channel.
/// This method can be passed to the [io.HttpServer.listen] method.
Function createIoHandler(EventSourcePublisher publisher,
    {String channel = "", bool gzip = false}) {
  void ioHandler(io.HttpRequest request) {
    io.HttpResponse response = request.response;

    // set content encoding to gzip if we allow it and the request supports it
    bool useGzip = gzip &&
        (request.headers.value(io.HttpHeaders.acceptEncodingHeader) ?? "")
            .contains("gzip");

    // set headers and status code
    response.statusCode = 200;
    response.headers.set("Content-Type", "text/event-stream; charset=utf-8");
    response.headers
        .set("Cache-Control", "no-cache, no-store, must-revalidate");
    response.headers.set("Connection", "keep-alive");
    if (useGzip) response.headers.set("Content-Encoding", "gzip");
    // a wait group to keep track of flushes in order not to close while
    // flushing
    WaitGroup flushes = WaitGroup();
    // flush the headers
    flushes.add(1);
    response.flush().then((_) => flushes.done());

    // create encoder for this connection
    var encodedSink = EventSourceEncoder(compressed: useGzip)
        .startChunkedConversion(response);

    // define the methods for pushing events and closing the connection
    void onEvent(Event event) {
      encodedSink.add(event);
      flushes.add(1);
      response.flush().then((_) => flushes.done());
    }

    void onClose() {
      flushes.wait().then((_) => response.close());
    }

    // initialize the new subscription
    publisher.newSubscription(
        onEvent: onEvent,
        onClose: onClose,
        channel: channel,
        lastEventId: request.headers.value("Last-Event-ID"));
  }

  return ioHandler;
}
