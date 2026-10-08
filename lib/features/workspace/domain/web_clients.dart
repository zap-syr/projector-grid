import '../../../core/services/web_auth.dart';

/// One signed-in browser as Preferences and the status bar show it.
class WebClient {
  const WebClient({
    required this.id,
    required this.ip,
    required this.role,
    required this.pages,
    required this.lastSeen,
  });

  /// The session token; only used to sign this one client out.
  final String id;
  final String ip;
  final WebRole role;

  /// Open tabs. Zero is a session whose page is closed: it still lasts
  /// [WebAuth.idleTimeout], so the browser comes back without a PIN.
  final int pages;
  final DateTime lastSeen;

  bool get online => pages > 0;

  @override
  bool operator ==(Object other) =>
      other is WebClient &&
      other.id == id &&
      other.ip == ip &&
      other.role == role &&
      other.pages == pages &&
      other.lastSeen == lastSeen;

  @override
  int get hashCode => Object.hash(id, ip, role, pages, lastSeen);
}

/// [sessions] as clients: online first (operators, then by IP), then closed
/// pages, most recently seen first.
List<WebClient> webClients(
  Iterable<WebSession> sessions,
  int Function(String token) pagesOf,
) {
  final clients = [
    for (final s in sessions)
      WebClient(
        id: s.token,
        ip: s.ip,
        role: s.role,
        pages: pagesOf(s.token),
        lastSeen: s.lastSeen,
      ),
  ];
  int rank(WebClient c) => !c.online
      ? 2
      : c.role == WebRole.operator
      ? 0
      : 1;
  clients.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.online ? a.ip.compareTo(b.ip) : b.lastSeen.compareTo(a.lastSeen);
  });
  return clients;
}
