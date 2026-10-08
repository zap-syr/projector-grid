import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/web_clients.dart';

part 'web_clients_provider.g.dart';

/// Signed-in web clients, kept by [WebServerNotifier] so the status bar and
/// Preferences can watch them without the server's internals.
@Riverpod(keepAlive: true)
class WebClients extends _$WebClients {
  @override
  List<WebClient> build() => const [];

  void set(List<WebClient> clients) => state = clients;

  @override
  bool updateShouldNotify(List<WebClient> previous, List<WebClient> next) =>
      !listEquals(previous, next);
}
