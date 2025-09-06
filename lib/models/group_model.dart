class Group {
  final String id;
  final String name;
  final String type; // 'familia' o 'piso'
  final List<String> memberIds;

  Group({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      memberIds: List<String>.from(json['memberIds']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'memberIds': memberIds,
  };
}