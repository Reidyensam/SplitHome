import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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
          .limit(10)
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

                return Card(
                  color: isRead ? Colors.grey[200] : Colors.white,
                  child: ListTile(
                    title: Text(message),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          createdAt is String
                              ? createdAt
                              : createdAt.toString(),
                        ),
                        if (type == 'invitation' && status == 'pending')
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _acceptInvitation(notif),
                                child: const Text('Aceptar'),
                              ),
                              TextButton(
                                onPressed: () => _rejectInvitation(notif['id']),
                                child: const Text('Rechazar'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: isRead
                        ? const Icon(Icons.check, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.mark_email_read),
                            onPressed: () => _markAsRead(notif['id']),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
