library codec_test;

import "dart:async";
import "dart:convert";

import "package:test/test.dart";

import "package:eventsource/src/decoder.dart";
import "package:eventsource/src/encoder.dart";
import "package:eventsource/src/event.dart";

Map<Event, String> _vectors = {
  Event(id: "1", event: "Add", data: "This is a test"):
      "id: 1\nevent: Add\ndata: This is a test\n\n",
  Event(data: "This message, it\nhas two lines."):
      "data: This message, it\ndata: has two lines.\n\n",
};

void main() {
  group("encoder", () {
    test("vectors", () {
      var encoder = EventSourceEncoder();
      for (Event event in _vectors.keys) {
        var encoded = _vectors[event]!;
        expect(encoder.convert(event), equals(utf8.encode(encoded)));
      }
    });
    //TODO add gzip test
  });

  group("decoder", () {
    test("vectors", () async {
      for (Event event in _vectors.keys) {
        var encoded = _vectors[event]!;
        var stream = Stream<String>.fromIterable([encoded])
            .transform(Utf8Encoder())
            .transform(EventSourceDecoder());
        stream.listen(expectAsync1((decodedEvent) {
          expect(decodedEvent.id, equals(event.id));
          expect(decodedEvent.event, equals(event.event));
          expect(decodedEvent.data, equals(event.data));
        }, count: 1));
      }
    });
    test("pass retry value", () async {
      Event event = Event(id: "1", event: "Add", data: "This is a test");
      String encodedWithRetry =
          "id: 1\nevent: Add\ndata: This is a test\nretry: 100\n\n";
      var changeRetryValue = expectAsync1((Duration value) {
        expect(value.inMilliseconds, equals(100));
      }, count: 1);
      var stream = Stream.fromIterable([encodedWithRetry])
          .transform(Utf8Encoder())
          .transform(EventSourceDecoder(retryIndicator: changeRetryValue));
      stream.listen(expectAsync1((decodedEvent) {
        expect(decodedEvent.id, equals(event.id));
        expect(decodedEvent.event, equals(event.event));
        expect(decodedEvent.data, equals(event.data));
      }, count: 1));
    });
  });
}
