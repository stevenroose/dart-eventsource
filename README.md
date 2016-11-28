# eventsource

A library for using EventSource or Server-Sent Events (SSE). 
Both client and server functionality is provided.

This library implements the interface as described [here](https://html.spec.whatwg.org/multipage/comms.html#server-sent-events).

## Client usage

For more advanced usage, see the `example/` directory. 
Creating a new EventSource client is as easy as a single call.
The http package is used under the hood, so wherever this package works, this lbirary will also work.
Browser usage is slightly different.

```dart
EventSource eventSource = await EventSource.connect("http://example.com/events");
// in browsers, you need to pass a http.BrowserClient:
EventSource eventSource = await EventSource.connect("http://example.com/events", 
    client: new http.BrowserClient());
```

## Server usage

We recommend using [`shelf_eventsource`](https://pub.dartlang.org/packages/shelf_eventsource) for
serving Server-Sent Events. 
This library provides an `EventSourcePublisher` that manages subscriptions, channels, encoding.
We refer to documentation in the [`shelf_eventsource`](https://pub.dartlang.org/packages/shelf_eventsource)
package for more information.

This library also includes a server provider for `dart:io`'s `HttpServer` in `io_server.dart`.
However, it has some issues with data flushing that are yet to be resolved, so we recommend using
shelf instead.

## Licensing

This project is available under the MIT license, as can be found in the LICENSE file.