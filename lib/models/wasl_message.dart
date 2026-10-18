class WaslMessage {
final String id;
final String conversationId;
final String senderId;
final String senderName;
final String text;
final DateTime sentAt;
final bool isMine;
final bool isDelivered;

const WaslMessage({
required this.id,
required this.conversationId,
required this.senderId,
required this.senderName,
required this.text,
required this.sentAt,
required this.isMine,
this.isDelivered = false,
});

Map<String, dynamic> toJson() => {
'id': id,
'conversationId': conversationId,
'senderId': senderId,
'senderName': senderName,
'text': text,
'sentAt': sentAt.toIso8601String(),
'isMine': isMine,
'isDelivered': isDelivered,
};

factory WaslMessage.fromJson(Map<String, dynamic> json) {
return WaslMessage(
id: json['id'] as String,
conversationId: json['conversationId'] as String,
senderId: json['senderId'] as String,
senderName: json['senderName'] as String,
text: json['text'] as String,
sentAt: DateTime.parse(json['sentAt'] as String),
isMine: json['isMine'] as bool? ?? false,
isDelivered: json['isDelivered'] as bool? ?? false,
);
}
}