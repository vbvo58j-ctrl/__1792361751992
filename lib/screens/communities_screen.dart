
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community.dart';
import '../services/community_store.dart';
import 'chat_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final CommunityStore _store = CommunityStore();

  List<WaslCommunity> _communities = [];
  bool _loading = true;
  String _userId = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _userId = prefs.getString('wasl_user_id') ??
        DateTime.now().microsecondsSinceEpoch.toString();
    _userName = prefs.getString('wasl_user_name') ?? 'مستخدم وصل';

    await prefs.setString('wasl_user_id', _userId);
    await prefs.setString('wasl_user_name', _userName);

    await _reload();
  }

  Future<void> _reload() async {
    try {
      final result = await _store.getCommunities();
      if (!mounted) return;

      setState(() {
        _communities = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _message('تعذر تحميل المجتمعات: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _createCommunity() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء مجتمع'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'اسم المجتمع',
            hintText: 'مثال: مجتمع الأصدقاء',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty) return;

    try {
      final community = await _store.createCommunity(
        name: name,
        ownerId: _userId,
        ownerName: _userName,
      );

      await _reload();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تم إنشاء المجتمع محليًا'),
          content: SelectableText(
            'اسم المجتمع: ${community.name}\n\n'
            'رمز المجتمع:\n${community.joinCode}\n\n'
            'احتفظ بالرمز. مشاركة الرمز وحدها لا تنقل طلبات الانضمام '
            'بين الهواتف؛ يلزم ربطها بالبلوتوث.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('تعذر إنشاء المجتمع: $e');
    }
  }

  Future<void> _joinCommunity() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController(text: _userName);

    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب الانضمام'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'رمز المجتمع',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسمك داخل المجتمع',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'code': codeController.text.trim(),
              'name': nameController.text.trim(),
            }),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );

    codeController.dispose();
    nameController.dispose();

    if (data == null) return;

    final code = data['code'] ?? '';
    final name = data['name'] ?? '';

    if (code.isEmpty || name.isEmpty) {
      _message('أدخل الرمز والاسم.');
      return;
    }

    try {
      final community = await _store.findByJoinCode(code);

      if (community == null) {
        _message(
          'لم يُعثر على هذا المجتمع في بيانات هذا الهاتف. '
          'الانضمام من هاتف آخر يحتاج إلى اتصال البلوتوث.',
        );
        return;
      }

      await _store.requestJoin(
        joinCode: code,
        memberId: _userId,
        memberName: name,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wasl_user_name', name);
      _userName = name;

      await _reload();
      _message('سُجل الطلب محليًا بانتظار موافقة المنشئ.');
    } catch (e) {
      _message('تعذر إرسال الطلب: $e');
    }
  }

  Future<void> _openCommunity(WaslCommunity community) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityDetailsScreen(
          communityId: community.id,
          userId: _userId,
          onChanged: _reload,
        ),
      ),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وصل - المجتمعات'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _communities.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_outlined, size: 72),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد مجتمعات محفوظة على هذا الهاتف',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'أنشئ مجتمعًا جديدًا للبدء.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _communities.length,
                  itemBuilder: (context, index) {
                    final community = _communities[index];
                    final approved = community.members
                        .where((m) => m.status == MemberStatus.approved)
                        .length;
                    final pending = community.members
                        .where((m) => m.status == MemberStatus.pending)
                        .length;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.groups),
                        ),
                        title: Text(community.name),
                        subtitle: Text(
                          'الأعضاء المقبولون: $approved'
                          '${pending > 0 ? ' • طلبات معلقة: $pending' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _openCommunity(community),
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join_community',
            onPressed: _joinCommunity,
            icon: const Icon(Icons.login),
            label: const Text('طلب انضمام'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_community',
            onPressed: _createCommunity,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء مجتمع'),
          ),
        ],
      ),
    );
  }
}

class CommunityDetailsScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final Future<void> Function() onChanged;

  const CommunityDetailsScreen({
    super.key,
    required this.communityId,
    required this.userId,
    required this.onChanged,
  });

  @override
  State<CommunityDetailsScreen> createState() =>
      _CommunityDetailsScreenState();
}

class _CommunityDetailsScreenState
    extends State<CommunityDetailsScreen> {
  final CommunityStore _store = CommunityStore();
  WaslCommunity? _community;
  bool _loading = true;

  bool get _isOwner => _community?.ownerId == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _store.getCommunities();
      final matches = all.where(
        (c) => c.id == widget.communityId,
      );

      if (!mounted) return;

      setState(() {
        _community = matches.isEmpty ? null : matches.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _notify('تعذر تحميل المجتمع: $e');
    }
  }

  void _notify(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _changeStatus(
    WaslMember member,
    MemberStatus status,
  ) async {
    try {
      await _store.setMemberStatus(
        communityId: widget.communityId,
        ownerId: widget.userId,
        memberId: member.id,
        status: status,
      );

      await _load();
      await widget.onChanged();

      _notify(
        status == MemberStatus.approved
            ? 'تم قبول العضو محليًا.'
            : status == MemberStatus.rejected
                ? 'تم رفض الطلب محليًا.'
                : 'تم حظر العضو محليًا.',
      );
    } catch (e) {
      _notify('تعذر تنفيذ العملية: $e');
    }
  }

  Future<void> _renameCommunity() async {
    final controller = TextEditingController(
      text: _community?.name ?? '',
    );

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير اسم المجتمع'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) return;

    try {
      await _store.renameCommunity(
        communityId: widget.communityId,
        ownerId: widget.userId,
        newName: value,
      );

      await _load();
      await widget.onChanged();
    } catch (e) {
      _notify('تعذر تغيير الاسم: $e');
    }
  }

  Future<void> _renameMember(WaslMember member) async {
    final controller = TextEditingController(text: member.name);

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير اسم العضو'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) return;

    try {
      await _store.renameMember(
        communityId: widget.communityId,
        ownerId: widget.userId,
        memberId: member.id,
        newName: value,
      );

      await _load();
    } catch (e) {
      _notify('تعذر تغيير اسم العضو: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = _community;

    return Scaffold(
      appBar: AppBar(
        title: Text(community?.name ?? 'تفاصيل المجتمع'),
        actions: [
          if (_isOwner)
            IconButton(
              onPressed: _renameCommunity,
              tooltip: 'تغيير اسم المجتمع',
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : community == null
              ? const Center(child: Text('المجتمع غير موجود.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
Card(
  child: ListTile(
    leading: const CircleAvatar(
      child: Icon(Icons.chat_bubble_outline),
    ),
    title: const Text('محادثة المجتمع'),
    subtitle: const Text('افتح رسائل هذا المجتمع'),
    trailing: const Icon(Icons.chevron_left),
    onTap: () async {
      final prefs = await SharedPreferences.getInstance();

      final currentUserId =
          prefs.getString('wasl_user_id') ?? widget.userId;

      final currentUserName =
          prefs.getString('wasl_user_name') ?? 'مستخدم وصل';

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: widget.communityId,
            title: community.name,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ),
        ),
      );
    },
  ),
),
const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'رمز المجتمع',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                community.joinCode,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'الرمز محفوظ محليًا. مشاركة الرمز وحدها '
                                'لا تنقل الطلبات بين الأجهزة.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'الأعضاء والطلبات (${community.members.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...community.members.map((member) {
                        final isPending =
                            member.status == MemberStatus.pending;
                        final statusLabel = switch (member.status) {
                          MemberStatus.pending => 'بانتظار الموافقة',
                          MemberStatus.approved => 'مقبول',
                          MemberStatus.rejected => 'مرفوض',
                          MemberStatus.blocked => 'محظور',
                        };

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      member.isOwner
                                          ? Icons.admin_panel_settings
                                          : Icons.person,
                                    ),
                                  ),
                                  title: Text(member.name),
                                  subtitle: Text(statusLabel),
                                  trailing: member.isOwner
                                      ? const Text('المنشئ')
                                      : _isOwner
                                          ? PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'rename') {
                                                  _renameMember(member);
                                                } else if (value == 'block') {
                                                  _changeStatus(
                                                    member,
                                                    MemberStatus.blocked,
                                                  );
                                                } else if (value ==
                                                    'approve') {
                                                  _changeStatus(
                                                    member,
                                                    MemberStatus.approved,
                                                  );
                                                } else if (value ==
                                                    'reject') {
                                                  _changeStatus(
                                                    member,
                                                    MemberStatus.rejected,
                                                  );
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                if (isPending)
                                                  const PopupMenuItem(
                                                    value: 'approve',
                                                    child: Text('قبول الطلب'),
                                                  ),
                                                if (isPending)
                                                  const PopupMenuItem(
                                                    value: 'reject',
                                                    child: Text('رفض الطلب'),
                                                  ),
                                                if (member.status !=
                                                    MemberStatus.blocked)
                                                  const PopupMenuItem(
                                                    value: 'block',
                                                    child: Text('حظر العضو'),
                                                  ),
                                                const PopupMenuItem(
                                                  value: 'rename',
                                                  child: Text('تغيير الاسم'),
                                                ),
                                              ],
                                            )
                                          : null,
                                ),
                                if (_isOwner && isPending)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _changeStatus(
                                            member,
                                            MemberStatus.rejected,
                                          ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('رفض'),
                                        ),
                                      ),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => _changeStatus(
                                            member,
                                            MemberStatus.approved,
                                          ),
                                          icon: const Icon(Icons.check),
                                          label: const Text('قبول'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}