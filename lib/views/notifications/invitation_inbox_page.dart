import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationInboxPage extends StatefulWidget {
  const InvitationInboxPage({super.key});

  @override
  State<InvitationInboxPage> createState() => _InvitationInboxPageState();
}

class _InvitationInboxPageState extends State<InvitationInboxPage> {
  List<Map<String, dynamic>> invitations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('group_invitations')
        .select('id, group_id, groups(name), invited_by')
        .eq('user_id', userId)
        .eq('status', 'pending');

    setState(() {
      invitations = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _respondToInvitation(String invitationId, String groupId, String status) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('group_invitations')
        .update({'status': status})
        .eq('id', invitationId);

    if (status == 'accepted') {
      await Supabase.instance.client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role_in_group': 'member',
      });
    }

    await notifyAdmin(invitationId, status);
    await _loadInvitations();
  }

  Future<void> notifyAdmin(String invitationId, String status) async {
    final invitation = await Supabase.instance.client
        .from('group_invitations')
        .select('invited_by, groups(name)')
        .eq('id', invitationId)
        .single();

    final adminId = invitation['invited_by'];
    final groupName = invitation['groups']['name'];

    await Supabase.instance.client.from('notifications').insert({
      'user_id': adminId,
      'message': 'Un usuario ha "$status" la invitación al grupo "$groupName"',
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitaciones pendientes'),
      ),
      body: invitations.isEmpty
          ? const Center(child: Text('No tienes invitaciones pendientes'))
          : ListView.builder(
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                final groupName = invitation['groups']['name'];
                final invitationId = invitation['id'];
                final groupId = invitation['group_id'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('Grupo: $groupName'),
                    subtitle: const Text('¿Deseas aceptar o rechazar esta invitación?'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _respondToInvitation(invitationId, groupId, 'accepted'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _respondToInvitation(invitationId, groupId, 'rejected'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}