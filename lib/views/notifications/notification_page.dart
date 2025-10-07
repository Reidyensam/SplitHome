import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool get hasUnreadNotifications {
  return notifications.any((n) => n['read'] != true);
}
    bool _allRead = false;

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
Future<void> _markAllNotificationsAsRead() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  try {
    await Supabase.instance.client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId);

    setState(() {
      notifications = notifications.map((n) {
        n['read'] = true;
        return n;
      }).toList();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Todas las notificaciones fueron marcadas como leídas'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al marcar como leído: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  Future<void> _loadNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      print('🔍 Cargando notificaciones para: $userId');

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 10));

      for (final notif in response) {
        print(
          '📨 Notificación cargada: ${notif['type']} - ${notif['message']}',
        );
      }

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
              _allRead = false; // 🔄 reactiva el color del ícono
            });
          }
        },
      )
      .subscribe();
}

  void _openGroup(Map<String, dynamic> notif) {
  final groupId = notif['group_id'];
  final message = notif['message']?.toString() ?? '';

  final groupLine = message
      .split('\n')
      .cast<String>() // 🔧 fuerza cada línea como String
      .firstWhere(
        (String line) => line.startsWith('En el grupo:'),
        orElse: () => '',
      );

  final groupName = groupLine
      .replaceFirst('En el grupo:', '')
      .trim()
      .replaceAll('"', '');

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
      case 'expense_add':
        return Icon(Icons.add_circle_outline, color: color);
      case 'expense_edit':
        return Icon(Icons.edit, color: color);
      case 'expense_delete':
        return Icon(Icons.delete_outline, color: color);
      default:
        return Icon(Icons.notifications, color: color);
    }
  }

  String buildNotificationHeader(String type, String actorName) {
    switch (type) {
      case 'expense_add':
        return '➕ $actorName agregó un gasto';
      case 'expense_edit':
        return '✏️ $actorName editó un gasto';
      case 'expense_delete':
        return '🗑️ $actorName eliminó un gasto';
      case 'mention':
        return '$actorName te mencionó:';
      case 'reply':
        return '$actorName respondió:';
      case 'comment':
        return '$actorName comentó:';
      default:
        return '$actorName realizó una acción';
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
  actions: [
    
    
    Padding(
  padding: const EdgeInsets.only(right: 12.0),
  child: TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.5, end: hasUnreadNotifications ? 1.08 : 1.0),
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeInOut,
    builder: (context, scale, child) {
      return Transform.scale(
        scale: scale,
        child: IconButton(
          icon: const Icon(Icons.done_all),
          color: _allRead ? Colors.grey[300] : Colors.white,
          tooltip: 'Marcar todo como leído',
          onPressed: () async {
            await _markAllNotificationsAsRead();
            setState(() => _allRead = true);
          },
        ),
      );
    },
  ),
),
  ],
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        buildNotificationHeader(
                                          type,
                                          actorName,
                                        ),
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      formatDate(createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
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
