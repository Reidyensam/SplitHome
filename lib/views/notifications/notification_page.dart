import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'package:splithome/views/groups/group_detail_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> notifications = [];
  RealtimeChannel? _notificationChannel;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.realtime.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        notifications = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar notificaciones: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _subscribeToNotifications() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _notificationChannel = Supabase.instance.client
        .channel('notifications_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newNotif = payload.newRecord;
            if (newNotif != null && newNotif['user_id'] == userId) {
              setState(() {
                notifications.insert(0, newNotif);
              });
            }
          },
        )
        .subscribe();
  }

  void _openGroup(Map<String, dynamic> notif) {
    final groupId = notif['group_id'];
    final groupName = notif['group_name'] ?? 'Grupo';

    if (groupId == null) return;

    Navigator.pushNamed(
      context,
      '/group_detail_page',
      arguments: {'groupId': groupId, 'groupName': groupName},
    );

    _markAsRead(notif['id']);
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      debugPrint('Error al marcar como leído: $e');
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> notification) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final groupId = notification['group_id'];
      final notificationId = notification['id'];
      if (userId == null || groupId == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'status': 'accepted', 'read': true})
          .eq('id', notificationId);

      await Supabase.instance.client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role_in_group': 'member',
      });

      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      debugPrint('Error al aceptar invitación: $e');
    }
  }

  Future<void> _rejectInvitation(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'status': 'rejected', 'read': true})
          .eq('id', notificationId);
      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      debugPrint('Error al rechazar invitación: $e');
    }
  }

  String formatDate(dynamic date) {
    final parsed = date is String ? DateTime.parse(date) : date as DateTime;
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }

  Icon getNotificationIcon(String type, bool isRead) {
    final color = isRead ? Colors.grey : AppColors.primary;
    switch (type) {
      case 'invitation':
        return Icon(Icons.group_add, color: color);
      case 'comment':
        return Icon(Icons.comment, color: color);
      case 'reply':
        return Icon(Icons.reply, color: color);
      case 'mention':
        return Icon(Icons.alternate_email, color: color);
      case 'file':
        return Icon(Icons.attach_file, color: color);
      case 'task':
        return Icon(Icons.assignment, color: color);
      case 'system':
        return Icon(Icons.info, color: color);
      default:
        return Icon(Icons.notifications, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: AppColors.primary,
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No hay notificaciones'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final message = notif['message'];
                final createdAt = notif['created_at'] ?? DateTime.now();
                final isRead = notif['read'] ?? false;
                final type = notif['type'];
                final status = notif['status'] ?? 'pending';
                final actorName = notif['actor_name'] ?? 'Alguien';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    getNotificationIcon(type, isRead),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openGroup(notif),
                        child: Card(
                          color: isRead
                              ? Theme.of(context).cardColor.withOpacity(0.6)
                              : Theme.of(context).cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == 'mention'
                                      ? '$actorName te mencionó:'
                                      : '$actorName comentó:',
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...message.split('\n').map((line) {
                                  final isGroupLine = line.startsWith(
                                    'En el grupo:',
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: line.startsWith('“')
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        fontWeight: isGroupLine
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 4),
                                Text(
                                  formatDate(createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (type == 'invitation' && status == 'pending')
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _acceptInvitation(notif),
                                        child: const Text('Aceptar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _rejectInvitation(notif['id']),
                                        child: const Text('Rechazar'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
