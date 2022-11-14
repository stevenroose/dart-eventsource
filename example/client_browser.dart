import "package:eventsource/eventsource.dart";
import "package:http/browser_client.dart";

main() async {
  // Because EventSource uses the http package, browser usage needs a special
  // approach. This will change once https://github.com/dart-lang/http/issues/1
  // is fixed.

  EventSource eventSource = await EventSource.connect(
      "http://example.org/events",
      client: BrowserClient());
  // listen for events
  eventSource.listen((Event event) {
    print("New event:");
    print("  event: ${event.event}");
    print("  data: ${event.data}");
  });

  // If you know the last event.id from a previous connection, you can try this:

  String lastId = "iknowmylastid";
  eventSource = await EventSource.connect(
    "http://example.org/events",
    client: BrowserClient(),
    lastEventId: lastId,
  );
  // listen for events
  eventSource.listen((Event event) {
    print("New event:");
    print("  event: ${event.event}");
    print("  data: ${event.data}");
  });
}
