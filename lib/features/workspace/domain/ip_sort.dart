/// Zero-padded dotted-quad so a plain string compare orders IPs numerically
/// (`10.0.0.9` before `10.0.0.10`).
String ipSortKey(String ip) => ip
    .split('.')
    .map((o) => (int.tryParse(o) ?? 0).toString().padLeft(3, '0'))
    .join('.');
