import 'dart:async';

class RestaurantOrdersSyncBus {
  RestaurantOrdersSyncBus._();

  static final RestaurantOrdersSyncBus instance = RestaurantOrdersSyncBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get events => _controller.stream;

  void requestRefresh() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }
}
