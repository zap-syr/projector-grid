class CustomCommand {
  final String id;
  final String name;
  final String command;

  const CustomCommand({
    required this.id,
    required this.name,
    required this.command,
  });

  /// OSC-safe slug derived from name.
  /// "House Lights!" → "house-lights"
  String get oscSlug => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  String get oscAddress => '/prjmgr/custom/$oscSlug';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'command': command,
  };

  factory CustomCommand.fromJson(Map<String, dynamic> json) => CustomCommand(
    id: json['id'] as String,
    name: json['name'] as String,
    command: json['command'] as String,
  );
}
