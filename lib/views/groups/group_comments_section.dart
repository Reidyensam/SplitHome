import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splithome/widgets/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class GroupCommentsSection extends StatefulWidget {
  final String groupId;
  final int month;
  final int year;
  final String? highlightCommentId;

  const GroupCommentsSection({
    required this.groupId,
    required this.month,
    required this.year,
    this.highlightCommentId,
    super.key,
  });

  @override
  State<GroupCommentsSection> createState() => _GroupCommentsSectionState();
}

class _GroupCommentsSectionState extends State<GroupCommentsSection> {
  bool isSending = false;

  List<Map<String, dynamic>> comments = [];
  final TextEditingController commentController = TextEditingController();
  final TextEditingController editController = TextEditingController();
  final Map<String, TextEditingController> replyControllers = {};
  String? editingCommentId;
  int unreadCount = 0;
  bool showCommentsExpanded = true;
  DateTime lastSeen = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, bool> showNewTag = {};
  final Set<String> alreadyTagged = {};

  Future<void> createNotification({
    required String userId,
    required String type,
    required String message,
    required String actorName,
    required String groupId,
    required int month,
    required int year,
  }) async {
    await Supabase.instance.client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'message': message,
      'actor_name': actorName,
      'group_id': groupId,
      'month': month,
      'year': year,
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
    });
  }

  Set<String> extractMentions(String content) {
    final regex = RegExp(r'@([\wáéíóúÁÉÍÓÚñÑ]+)');
    return regex.allMatches(content).map((m) => m.group(1)!).toSet();
  }

  Widget _buildContentWithMentions(String content, {bool isRoot = false}) {
    final words = content.split(' ');
    return Text.rich(
      TextSpan(
        children: words.map((word) {
          final isMention = word.startsWith('@');
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              fontSize: isRoot ? 17 : 14,
              color: isMention
                  ? const Color.fromARGB(255, 165, 61, 206)
                  : const Color.fromARGB(255, 223, 223, 223),
              fontWeight: isMention ? FontWeight.bold : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _loadComments() async {
    final response = await Supabase.instance.client
        .from('group_comments')
        .select('*, users(name)')
        .eq('group_id', widget.groupId)
        .eq('month', widget.month)
        .eq('year', widget.year)
        .order('created_at');

    if (mounted) {
      final loaded = List<Map<String, dynamic>>.from(response);

      setState(() {
        comments = loaded;
        unreadCount = comments
            .where((c) => DateTime.parse(c['created_at']).isAfter(lastSeen))
            .length;

        for (final c in loaded) {
          final id = c['id'] as String;
          final isNew = DateTime.parse(c['created_at']).isAfter(lastSeen);
          if (isNew && showNewTag[id] != true && !alreadyTagged.contains(id)) {
            showNewTag[id] = true;
            alreadyTagged.add(id);

            Timer(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  showNewTag[id] = false;
                });
              }
            });
          }
        }
      });
    }
  }

  Future<void> _addComment({String? parentId}) async {
    if (isSending) return;
    setState(() => isSending = true);

    final controller = parentId == null
        ? commentController
        : replyControllers[parentId] ?? TextEditingController();
    final content = controller.text.trim();
    if (content.isEmpty) {
      setState(() => isSending = false);
      return;
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      setState(() => isSending = false);
      return;
    }

    final currentUserName =
        Supabase.instance.client.auth.currentUser?.userMetadata?['name'] ??
        'Alguien';

    final response =
        await Supabase.instance.client.from('group_comments').insert({
          'group_id': widget.groupId,
          'user_id': currentUserId,
          'month': widget.month,
          'year': widget.year,
          'content': content,
          'parent_id': parentId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).select();

    controller.clear();
    await _loadComments();

    final groupResponse = await Supabase.instance.client
        .from('groups')
        .select('name')
        .eq('id', widget.groupId)
        .single();

    final groupName = groupResponse['name'] ?? 'Grupo desconocido';
    final preview = content.length > 40
        ? '${content.substring(0, 40)}…'
        : content;
    final formattedMessage = '“$preview”\nEn el grupo: "$groupName"';

    if (parentId != null) {
      final parentComment = comments.firstWhere(
        (c) => c['id'] == parentId,
        orElse: () => {},
      );
      final targetUserId = parentComment['user_id'];

      if (targetUserId != null && targetUserId != currentUserId) {
        await createNotification(
          userId: targetUserId,
          type: 'reply',
          message: formattedMessage,
          actorName: currentUserName,
          groupId: widget.groupId,
          month: widget.month,
          year: widget.year,
        );
      }

      await notifyGroupReply(
  actorId: currentUserId,
  actorName: currentUserName,
  groupId: widget.groupId,
  month: widget.month,
  year: widget.year,
  message: formattedMessage,
  excludeUserId: targetUserId ?? '',
  debug: true,
);
    } else {
      await notifyGroupComment(
        actorId: currentUserId,
        actorName: currentUserName,
        groupId: widget.groupId,
        month: widget.month,
        year: widget.year,
        message: formattedMessage,
      );
    }

    if (mounted) setState(() => isSending = false);
  }

  Future<void> notifyGroupComment({
    required String actorId,
    required String actorName,
    required String groupId,
    required int month,
    required int year,
    required String message,
    bool debug = false,
  }) async {
    final members = await Supabase.instance.client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);

    for (final member in members) {
      final targetUserId = member['user_id']?.toString().trim();
      final actorTrimmed = actorId.trim();

      if (targetUserId == null || targetUserId == actorTrimmed) {
        if (debug) print('🔕 Ignorado (autor): $targetUserId');
        continue;
      }

      if (debug) print('🔔 Notificando a: $targetUserId');

      await createNotification(
        userId: targetUserId,
        type: 'comment',
        message: message,
        actorName: actorName,
        groupId: groupId,
        month: month,
        year: year,
      );
    }
  }

  Future<void> notifyGroupReply({
  required String actorId,
  required String actorName,
  required String groupId,
  required int month,
  required int year,
  required String message,
  required String excludeUserId,
  bool debug = false,
}) async {
  final members = await Supabase.instance.client
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId);

  for (final member in members) {
    final targetUserId = member['user_id']?.toString().trim();
    if (targetUserId == null || targetUserId == actorId) {
      if (debug) print('🔕 Ignorado (autor de la respuesta): $targetUserId');
      continue;
    }

    if (targetUserId == excludeUserId) {
      if (debug) print('🔕 Ignorado (autor original del comentario): $targetUserId');
      continue;
    }

    if (debug) print('🔔 Notificando reply grupal a: $targetUserId');

    await createNotification(
      userId: targetUserId,
      type: 'reply',
      message: message,
      actorName: actorName,
      groupId: groupId,
      month: month,
      year: year,
    );
  }
}

  Future<void> _updateComment(String commentId) async {
    final content = editController.text.trim();
    if (content.isEmpty) return;

    await Supabase.instance.client
        .from('group_comments')
        .update({
          'content': content,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);

    setState(() {
      editingCommentId = null;
      editController.clear();
    });

    await _loadComments();
  }

  Future<void> _deleteComment(String commentId) async {
    await Supabase.instance.client
        .from('group_comments')
        .delete()
        .eq('id', commentId);

    await _loadComments();
  }

  void _confirmDelete(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar comentario?'),
        content: const Text('Esta acción no se puede deshacer. ¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteComment(commentId);
            },
          ),
        ],
      ),
    );
  }

  void _openGroup(Map<String, dynamic> notif) {
    final groupId = notif['group_id'];
    final month = notif['month'];
    final year = notif['year'];
    final commentId = notif['comment_id']; // opcional

    if (groupId == null || month == null || year == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCommentsSection(
          groupId: groupId,
          month: month,
          year: year,
          highlightCommentId: commentId,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLastSeenAndComments();

    Supabase.instance.client
        .channel('group_comments_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_comments',
          callback: (payload) {
            _loadComments();
          },
        )
        .subscribe();
  }

  void _loadLastSeenAndComments() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(
      'lastSeen_${widget.groupId}_${widget.month}_${widget.year}',
    );
    if (stored != null) {
      lastSeen = DateTime.parse(stored);
    }
    await _loadComments();
  }

  @override
  void didUpdateWidget(covariant GroupCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != oldWidget.month || widget.year != oldWidget.year) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    editController.dispose();
    for (final controller in replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin =
        Supabase.instance.client.auth.currentUser?.userMetadata?['role'] ==
        'admin';
    final rootComments = comments.where((c) => c['parent_id'] == null).toList()
      ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
    final replies = comments.where((c) => c['parent_id'] != null).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) async {
          setState(() {
            showCommentsExpanded = expanded;
            if (expanded) {
              lastSeen = DateTime.now();
              unreadCount = 0;
            }
          });

          if (expanded) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'lastSeen_${widget.groupId}_${widget.month}_${widget.year}',
              lastSeen.toIso8601String(),
            );
          }
        },
        leading: const Icon(Icons.comment_outlined, color: Colors.white),
        title: Row(
          children: [
            const Text(
              'Comentarios',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        children: [
          const SizedBox(height: 12),
          if (rootComments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No hay comentarios aún. Sé el primero en comentar.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...rootComments.map((c) {
              final isOwner = c['user_id'] == currentUserId;
              final isEditing = editingCommentId == c['id'];
              final commentReplies =
                  replies.where((r) => r['parent_id'] == c['id']).toList()
                    ..sort(
                      (a, b) => a['created_at'].compareTo(b['created_at']),
                    );
              final nombre = c['users']['name'] ?? 'Usuario';
              final color =
                  Colors.primaries[nombre.hashCode % Colors.primaries.length];
              replyControllers.putIfAbsent(
                c['id'],
                () => TextEditingController(),
              );

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            child: Text(
                              nombre[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedOpacity(
                                  opacity: showNewTag[c['id']] == true
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(milliseconds: 600),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Nuevo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwner)
                            Row(
                              children: [
                                if (!isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      if (mounted) {
                                        setState(() {
                                          editingCommentId = c['id'];
                                          editController.text = c['content'];
                                        });
                                      }
                                    },
                                  ),
                                if (isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.check, size: 20),
                                    onPressed: () => _updateComment(c['id']),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _confirmDelete(c['id']),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatearFecha(
                          c['created_at'],
                          updatedIso: c['updated_at'],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 216, 216, 216),
                        ),
                      ),
                      const SizedBox(height: 4),
                      isEditing
                          ? TextField(
                              controller: editController,
                              decoration: const InputDecoration(
                                labelText: 'Editar comentario',
                              ),
                            )
                          : _buildContentWithMentions(
                              c['content'],
                              isRoot: true,
                            ),
                      const SizedBox(height: 8),
                      ...commentReplies.map((r) {
                        final isReplyOwner = r['user_id'] == currentUserId;
                        final isReplyEditing = editingCommentId == r['id'];
                        final canEditOrDeleteReply = isReplyOwner || isAdmin;
                        final nombreR = r['users']['name'] ?? 'Usuario';

                        final colorR =
                            Colors.primaries[nombreR.hashCode %
                                Colors.primaries.length];

                        return Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 37, 37, 37)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                nombreR,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: colorR,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (showNewTag[r['id']] == true)
                                                AnimatedOpacity(
                                                  opacity: 1.0,
                                                  duration: const Duration(
                                                    milliseconds: 600,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Nuevo',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatearFecha(
                                              r['created_at'],
                                              updatedIso: r['updated_at'],
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color.fromARGB(
                                                255,
                                                180,
                                                180,
                                                180,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (canEditOrDeleteReply &&
                                            !isReplyEditing)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              if (mounted) {
                                                setState(() {
                                                  editingCommentId = r['id'];
                                                  editController.text =
                                                      r['content'];
                                                });
                                              }
                                            },
                                          ),
                                        if (canEditOrDeleteReply &&
                                            isReplyEditing)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check,
                                              size: 18,
                                            ),
                                            onPressed: () =>
                                                _updateComment(r['id']),
                                          ),
                                        if (canEditOrDeleteReply)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 18,
                                            ),
                                            color: Colors.red,
                                            onPressed: () =>
                                                _confirmDelete(r['id']),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                isReplyEditing
                                    ? TextField(
                                        controller: editController,
                                        decoration: const InputDecoration(
                                          labelText: 'Editar respuesta',
                                        ),
                                      )
                                    : _buildContentWithMentions(r['content']),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 1),
                      TextField(
                        controller: replyControllers[c['id']],
                        decoration: const InputDecoration(
                          labelText: 'Responder...',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _addComment(parentId: c['id']),
                          child: const Text('Responder'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          const Divider(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 206, 206, 206),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: commentController,
              style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              decoration: const InputDecoration(
                labelText: 'Escribe un comentario',
                labelStyle: TextStyle(color: Color.fromARGB(255, 22, 22, 22)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: isSending ? null : () => _addComment(),

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 37, 61, 197),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
