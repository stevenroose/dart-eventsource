library eventsource.server;

export "src/event.dart";

import "dart:async";

import "package:logging/logging.dart" as log;

import "src/event.dart";
import "src/event_cache.dart";
import "src/proxy_sink.dart";

/// An EventSource publisher. It can manage different channels of events.
/// This class forms the backbone of an EventSource server. To actually serve
/// a web server, use this together with [shelf_eventsource] or another server
/// implementation.
class EventSourcePublisher extends Sink<Event> {
  log.Logger logger;
  EventCache _cache;

  /// Create a new EventSource server.
  ///
  /// When using a cache, for efficient replaying, it is advisable to use a
  /// custom Event implementation that overrides the `Event.compareTo` method.
  /// F.e. if integer events are used, sorting should be done on integers and
  /// not on the string representations of them.
  /// If your Event's id properties are not incremental using
  /// [Comparable.compare], set [comparableIds] to false.
  EventSourcePublisher(
      {int cacheCapacity: 0,
      bool comparableIds: false,
      bool enableLogging: true}) {
    if (cacheCapacity > 0) {
      _cache = new EventCache(cacheCapacity: cacheCapacity);
    }
    if (enableLogging) {
      logger = new log.Logger("EventSourceServer");
    }
  }

  Map<String, List<ProxySink>> _subsByChannel = {};

  /// Creates a Sink for the specified channel.
  /// The `add` and `remove` methods of this channel are equivalent to the
  /// respective methods of this class with the specific channel passed along.
  Sink<Event> channel(String channel) => new ProxySink(
      onAdd: (e) => add(e, channels: [channel]),
      onClose: () => close(channels: [channel]));

  /// Add a publication to the specified channels.
  /// By default, only adds to the default channel.
  @override
  void add(Event event, {Iterable<String> channels: const [""]}) {
    for (String channel in channels) {
      List subs = _subsByChannel[channel];
      if (subs == null) {
        continue;
      }
      _logFiner(
          "Sending event on channel $channel to ${subs.length} subscribers.");
      for (var sub in subs) {
        sub.add(event);
      }
    }
    if (_cache != null) {
      _cache.add(event, channels);
    }
  }

  /// Close the specified channels.
  /// All the connections with the subscribers to this channels will be closed.
  /// By default only closes the default channel.
  @override
  void close({Iterable<String> channels: const [""]}) {
    for (String channel in channels) {
      List subs = _subsByChannel[channel];
      if (subs == null) {
        continue;
      }
      _logInfo("Closing channel $channel with ${subs.length} subscribers.");
      for (var sub in subs) {
        sub.close();
      }
    }
    if (_cache != null) {
      _cache.clear(channels);
    }
  }

  /// Close all the open channels.
  void closeAllChannels() => close(channels: _subsByChannel.keys);

  /// Initialize a new subscription and replay when possible.
  /// Should not be used by the user directly.
  void newSubscription(
      {Function onEvent,
      Function onClose,
      String channel,
      String lastEventId}) {
    _logFine("New subscriber on channel $channel.");
    // create a sink for the subscription
    var sub = new ProxySink(onAdd: onEvent, onClose: onClose);
    // save the subscription
    _subsByChannel.putIfAbsent(channel, () => []).add(sub);
    // replay past events
    if (_cache != null && lastEventId != null) {
      scheduleMicrotask(() {
        _logFine("Replaying events on channel $channel from id $lastEventId.");
        _cache.replay(sub, lastEventId, channel);
      });
    }
  }

  void _logInfo(message) {
    if (logger != null) {
      logger.log(log.Level.INFO, message);
    }
  }

  void _logFine(message) {
    if (logger != null) {
      logger.log(log.Level.FINE, message);
    }
  }

  void _logFiner(message) {
    if (logger != null) {
      logger.log(log.Level.FINER, message);
    }
  }
}
