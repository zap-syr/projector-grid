import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_auth.dart';
import 'package:projector_grid/features/workspace/domain/web_clients.dart';

void main() {
  final t = DateTime(2026, 10, 8, 12);

  test('online first, operators on top; closed pages by last seen', () {
    final sessions = [
      WebSession('closed-old', WebRole.operator, '10.0.0.9', t),
      WebSession('viewer-b', WebRole.viewer, '10.0.0.7', t),
      WebSession('closed-new', WebRole.viewer, '10.0.0.8', t.add(_min)),
      WebSession('viewer-a', WebRole.viewer, '10.0.0.3', t),
      WebSession('op', WebRole.operator, '10.0.0.5', t),
    ];
    const pages = {'viewer-b': 1, 'viewer-a': 2, 'op': 1};

    final clients = webClients(sessions, (token) => pages[token] ?? 0);

    expect(clients.map((c) => c.id), [
      'op',
      'viewer-a',
      'viewer-b',
      'closed-new',
      'closed-old',
    ]);
    expect(clients[1].pages, 2);
    expect(clients[3].online, isFalse);
  });

  test('clients with the same fields are equal', () {
    WebClient client(int pages) => WebClient(
      id: 'a',
      ip: '10.0.0.1',
      role: WebRole.viewer,
      pages: pages,
      lastSeen: t,
    );
    expect(client(1), client(1));
    expect(client(1), isNot(client(2)));
  });
}

const _min = Duration(minutes: 1);
