library eventsource.src.proxy_sink;

/// Just a simple [Sink] implementation that proxies the [add] and [close]
/// methods.
class ProxySink<T> implements Sink<T> {
  void Function(T) onAdd;
  void Function() onClose;
  ProxySink({required this.onAdd, required this.onClose});
  @override
  void add(t) => onAdd(t);
  @override
  void close() => onClose();
}
