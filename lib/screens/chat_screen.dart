import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wasl_message.dart';
import '../services/message_store.dart';
import '../services/bluetooth_classic_service.dart';

class ChatScreen extends StatefulWidget {
final String conversationId;
final String title;
final String currentUserId;
final String currentUserName;
final Future<void> Function(WaslMessage message)? onSendMessage;

const ChatScreen({
super.key,
required this.conversationId,
required this.title,
required this.currentUserId,
required this.currentUserName,
this.onSendMessage,
});

@override
State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
final MessageStore _store = MessageStore();
final BluetoothClassicService _bluetooth =
BluetoothClassicService.instance;

final TextEditingController _textController =
TextEditingController();
final ScrollController _scrollController = ScrollController();

final Set<String> _receivedIds = <String>{};

List<WaslMessage> _messages = [];
List<WaslDevice> _devices = [];

StreamSubscription<WaslEvent>? _subscription;

String? _selectedAddress;
String _connectionStatus = 'غير متصل';

bool _loading = true;
bool _sending = false;
bool _working = false;

@override
void initState() {
super.initState();
_loadMessages();
_listenToBluetooth();
}

Future<void> _loadMessages() async {
try {
final messages =
await _store.getMessages(widget.conversationId);

  if (!mounted) return;

  setState(() {
    _messages = messages;
    _receivedIds.addAll(messages.map((m) => m.id));
    _loading = false;
  });

  _scrollToBottom();
} catch (_) {
  if (!mounted) return;
  setState(() => _loading = false);
  _showNotice('تعذر تحميل سجل الرسائل.');
}

}

void _listenToBluetooth() {
_subscription = _bluetooth.events.listen(
_handleBluetoothEvent,
onError: (Object error) {
if (!mounted) return;
setState(() {
_connectionStatus = 'خطأ في أحداث البلوتوث';
});
},
);
}

void _handleBluetoothEvent(WaslEvent event) {
if (!mounted) return;

switch (event.type) {
  case 'connected':
    setState(() {
      _selectedAddress = event.address ?? _selectedAddress;
      _connectionStatus =
          'متصل: ${event.name ?? 'جهاز'}';
    });
    _showNotice('تم الاتصال بجهاز ${event.name ?? ''}');
    break;

  case 'disconnected':
    if (_selectedAddress == event.address) {
      setState(() {
        _selectedAddress = null;
        _connectionStatus = 'انقطع الاتصال';
      });
    }
    break;

  case 'message':
    final raw = event.message;
    if (raw != null) {
      _handleIncomingMessage(raw, event.address);
    }
    break;

  case 'connectionError':
  case 'serverError':
    setState(() => _connectionStatus = 'حدث خطأ في الاتصال');
    _showNotice(event.message ?? 'تعذر الاتصال بالبلوتوث.');
    break;

  case 'serverStarted':
    setState(() {
      _connectionStatus = 'جاهز لاستقبال الاتصالات';
    });
    break;

  case 'serverStopped':
    setState(() {
      _connectionStatus = 'الاستقبال متوقف';
    });
    break;
}

}

Future<void> _handleIncomingMessage(
String raw,
String? address,
) async {
try {
final dynamic decoded = jsonDecode(raw);

  if (decoded is! Map) return;

  final senderId = decoded['senderId']?.toString() ?? '';
  final senderName =
      decoded['senderName']?.toString() ?? 'مستخدم';
  final text = decoded['text']?.toString() ?? '';
  final messageId = decoded['id']?.toString() ??
      '${DateTime.now().microsecondsSinceEpoch}_$senderId';

  final incomingConversation =
      decoded['conversationId']?.toString() ?? '';

  if (text.trim().isEmpty ||
      senderId.isEmpty ||
      senderId == widget.currentUserId) {
    return;
  }

  // لا تعرض رسائل محادثة مختلفة في هذه المحادثة.
  if (incomingConversation.isNotEmpty &&
      incomingConversation != widget.conversationId) {
    return;
  }

  if (_receivedIds.contains(messageId)) return;

  final message = WaslMessage(
    id: messageId,
    conversationId: widget.conversationId,
    senderId: senderId,
    senderName: senderName,
    text: text,
    sentAt: DateTime.tryParse(
          decoded['sentAt']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now(),
    isMine: false,
  );

  _receivedIds.add(messageId);

  await _store.saveMessage(message);

  if (!mounted) return;

  setState(() {
    _messages.add(message);
    _selectedAddress ??= address;
  });

  _scrollToBottom();
} catch (_) {
  _showNotice('تعذر قراءة الرسالة المستلمة.');
}

}

Future<void> _prepareBluetooth() async {
if (_working) return;

setState(() => _working = true);

try {
  if (!await _bluetooth.isSupported()) {
    _showNotice('هذا الهاتف لا يدعم البلوتوث.');
    return;
  }

  final granted = await _bluetooth.requestPermissions();

  if (!granted) {
    _showNotice('امنح صلاحيات البلوتوث للتطبيق.');
    return;
  }

  if (!await _bluetooth.isEnabled()) {
    await _bluetooth.requestEnable();
    _showNotice('فعّل البلوتوث ثم اضغط الزر مرة أخرى.');
    return;
  }

  _devices = await _bluetooth.getPairedDevices();

  if (!mounted) return;

  await _showDevicePicker();
} on PlatformException catch (e) {
  _showNotice(e.message ?? 'تعذر تجهيز البلوتوث.');
} catch (e) {
  _showNotice('حدث خطأ أثناء تجهيز البلوتوث.');
} finally {
  if (mounted) setState(() => _working = false);
}

}

Future<void> _showDevicePicker() async {
if (!mounted) return;

final device = await showModalBottomSheet<WaslDevice>(
  context: context,
  builder: (sheetContext) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _devices.isEmpty
            ? const Text(
                'لا توجد أجهزة مقترنة.\n'
                'اقرن الهاتفين من إعدادات البلوتوث أولًا.',
                textAlign: TextAlign.center,
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'اختر جهازًا مقترنًا',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._devices.map(
                    (d) => ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(d.name),
                      subtitle: Text(d.address),
                      onTap: () =>
                          Navigator.pop(sheetContext, d),
                    ),
                  ),
                ],
              ),
      ),
    );
  },
);

if (device == null || !mounted) return;

setState(() {
  _selectedAddress = device.address;
  _connectionStatus = 'جارٍ الاتصال بـ ${device.name}...';
});

try {
  await _bluetooth.connect(device.address);
} on PlatformException catch (e) {
  if (mounted) {
    setState(() => _connectionStatus = 'فشل الاتصال');
  }
  _showNotice(e.message ?? 'تعذر الاتصال بالجهاز.');
} catch (_) {
  _showNotice('تعذر الاتصال بالجهاز.');
}

}

Future<void> _startListening() async {
if (_working) return;

setState(() => _working = true);

try {
  final supported = await _bluetooth.isSupported();

  if (!supported) {
    _showNotice('هذا الهاتف لا يدعم البلوتوث.');
    return;
  }

  final granted = await _bluetooth.requestPermissions();

  if (!granted) {
    _showNotice('امنح صلاحيات البلوتوث للتطبيق.');
    return;
  }

  if (!await _bluetooth.isEnabled()) {
    await _bluetooth.requestEnable();
    _showNotice('فعّل البلوتوث ثم حاول تشغيل الاستقبال.');
    return;
  }

  await _bluetooth.startServer();

  if (mounted) {
    setState(() {
      _connectionStatus = 'جارٍ تشغيل استقبال الرسائل...';
    });
  }
} on PlatformException catch (e) {
  _showNotice(e.message ?? 'تعذر تشغيل استقبال الرسائل.');
} catch (_) {
  _showNotice('حدث خطأ أثناء تشغيل الاستقبال.');
} finally {
  if (mounted) setState(() => _working = false);
}

}

Future<void> _sendMessage() async {
final text = _textController.text.trim();

if (text.isEmpty || _sending) return;

final address = _selectedAddress;

if (address == null || address.isEmpty) {
  _showNotice('اتصل بهاتف مقترن أولًا لإرسال الرسائل.');
  return;
}

setState(() => _sending = true);

final message = WaslMessage(
  id: '${DateTime.now().microsecondsSinceEpoch}_${widget.currentUserId}',
  conversationId: widget.conversationId,
  senderId: widget.currentUserId,
  senderName: widget.currentUserName,
  text: text,
  sentAt: DateTime.now(),
  isMine: true,
);

try {
  final payload = jsonEncode({
    'id': message.id,
    'conversationId': message.conversationId,
    'senderId': message.senderId,
    'senderName': message.senderName,
    'text': message.text,
    'sentAt': message.sentAt.toIso8601String(),
  });

  await _bluetooth.sendMessage(
    address: address,
    message: payload,
  );

  await _store.saveMessage(message);

  if (widget.onSendMessage != null) {
    await widget.onSendMessage!(message);
  }

  if (!mounted) return;

  _receivedIds.add(message.id);

  setState(() {
    _messages.add(message);
    _textController.clear();
  });

  _scrollToBottom();
} on PlatformException catch (e) {
  _showNotice(e.message ?? 'فشل إرسال الرسالة.');
} catch (e) {
  _showNotice('تعذر إرسال الرسالة. تحقق من الاتصال.');
} finally {
  if (mounted) setState(() => _sending = false);
}

}

void scrollToBottom() {
WidgetsBinding.instance.addPostFrameCallback(() {
if (!_scrollController.hasClients) return;

  _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );
});

}

void _showNotice(String text) {
if (!mounted) return;

ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

}

@override
void dispose() {
_subscription?.cancel();
_textController.dispose();
_scrollController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(widget.title),
Text(
_connectionStatus,
style: const TextStyle(fontSize: 12),
),
],
),
actions: [
IconButton(
tooltip: 'تشغيل استقبال الرسائل',
onPressed: _working ? null : _startListening,
icon: const Icon(Icons.bluetooth_searching),
),
IconButton(
tooltip: 'الاتصال بجهاز مقترن',
onPressed: _working ? null : _prepareBluetooth,
icon: const Icon(Icons.bluetooth_connected),
),
],
),
body: Column(
children: [
Expanded(
child: _loading
? const Center(child: CircularProgressIndicator())
: _messages.isEmpty
? const Center(
child: Text('لا توجد رسائل بعد. ابدأ المحادثة.'),
)
: ListView.builder(
controller: _scrollController,
padding: const EdgeInsets.all(12),
itemCount: _messages.length,
itemBuilder: (context, index) {
final message = _messages[index];
final mine = message.isMine;

                      return Align(
                        alignment: mine
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.8,
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    message.senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Text(message.text),
                              const SizedBox(height: 4),
                              Text(
                                '${message.sentAt.toLocal().hour.toString().padLeft(2, '0')}:'
                                '${message.sentAt.toLocal().minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

}
}