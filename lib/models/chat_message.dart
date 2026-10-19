class ChatMessage {
  final int? id;
  final String peerAddress;
  final String sender;
  final String body;
  final String created;
  final bool isMine;

  const ChatMessage({
    this.id,
    required this.peerAddress,
    required this.sender,
    required this.body,
    required this.created,
    required this.isMine,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'peer_address': peerAddress,
    'sender': sender,
    'body': body,
    'created': created,
    'is_mine': isMine ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
    id: map['id'] as int?,
    peerAddress: '${map['peer_address'] ?? ''}',
    sender: '${map['sender'] ?? ''}',
    body: '${map['body'] ?? ''}',
    created: '${map['created'] ?? ''}',
    isMine: map['is_mine'] == 1,
  );
}