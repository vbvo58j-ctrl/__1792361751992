
enum MemberStatus {
  pending,
  approved,
  rejected,
  blocked,
}

class WaslMember {
  final String id;
  String name;
  MemberStatus status;
  final bool isOwner;

  WaslMember({
    required this.id,
    required this.name,
    this.status = MemberStatus.pending,
    this.isOwner = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'isOwner': isOwner,
      };

  factory WaslMember.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'pending';

    return WaslMember(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'عضو',
      status: MemberStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => MemberStatus.pending,
      ),
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }
}

class WaslCommunity {
  final String id;
  String name;
  final String ownerId;
  final String joinCode;
  final List<WaslMember> members;
  final DateTime createdAt;

  WaslCommunity({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.joinCode,
    List<WaslMember>? members,
    DateTime? createdAt,
  })  : members = members ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'joinCode': joinCode,
        'createdAt': createdAt.toIso8601String(),
        'members': members.map((member) => member.toJson()).toList(),
      };

  factory WaslCommunity.fromJson(Map<String, dynamic> json) {
    return WaslCommunity(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      joinCode: json['joinCode'] as String,
      createdAt: DateTime.tryParse(
            json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      members: (json['members'] as List<dynamic>? ?? [])
          .map(
            (item) => WaslMember.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}