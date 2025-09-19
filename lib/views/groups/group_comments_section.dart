import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GroupCommentsSection extends StatefulWidget {
  final String groupId;
  final int month;
  final int year;

  const GroupCommentsSection({
    super.key,
    required this.groupId,
    required this.month,
    required this.year,
  });

  @override
  State<GroupCommentsSection> createState() => _GroupCommentsSectionState();
}

class _GroupCommentsSectionState extends State<GroupCommentsSection> {
  List<Map<String, dynamic>> comments = [];
  final TextEditingController commentController = TextEditingController();
  final TextEditingController editController = TextEditingController();
  final Map<String, TextEditingController> replyControllers = {};
  String? editingCommentId;

  Future<void> _loadComments() async {
    final client = Supabase.instance.client;
    final response = await client
        .from('group_comments')
        .select('*, users(name)')
        .eq('group_id', widget.groupId)
        .eq('month', widget.month)
        .eq('year', widget.year)
        .order('created_at');

    if (mounted) {
      setState(() {
        comments = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _addComment({String? parentId}) async {
    final controller = parentId == null
        ? commentController
        : replyControllers[parentId] ?? TextEditingController();
    final content = controller.text.trim();
    if (content.isEmpty) return;

    await Supabase.instance.client.from('group_comments').insert({
      'group_id': widget.groupId,
      'user_id': Supabase.instance.client.auth.currentUser?.id,
      'month': widget.month,
      'year': widget.year,
      'content': content,
      'parent_id': parentId,
    });

    controller.clear();
    await _loadComments();
  }

  Future<void> _updateComment(String commentId) async {
    final content = editController.text.trim();
    if (content.isEmpty) return;

    await Supabase.instance.client
        .from('group_comments')
        .update({
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', commentId);

    editingCommentId = null;
    editController.clear();
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

  @override
  void initState() {
    super.initState();
    _loadComments();
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

  Widget _buildContentWithMentions(String content, {bool isRoot = false}) {
    final words = content.split(' ');
    return Text.rich(
      TextSpan(
        children: words.map((word) {
          final isMention = word.startsWith('@');
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              fontSize: isRoot ? 16 : 16,
              color: isMention ? const Color.fromARGB(255, 165, 61, 206) : null,
              fontWeight: isMention ? FontWeight.bold : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final rootComments = comments.where((c) => c['parent_id'] == null).toList();
    final replies = comments.where((c) => c['parent_id'] != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💬 Comentarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 190, 190, 190),
          ),
        ),
        const SizedBox(height: 12),

        if (rootComments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No hay comentarios 💤',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ...rootComments.map((c) {
          final isOwner = c['user_id'] == currentUserId;
          final isEditing = editingCommentId == c['id'];
          final commentReplies = replies
              .where((r) => r['parent_id'] == c['id'])
              .toList();
          final nombre = c['users']['name'] ?? 'Usuario';
          final color =
              Colors.primaries[nombre.hashCode % Colors.primaries.length];
          replyControllers.putIfAbsent(c['id'], () => TextEditingController());

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
                        child: Text(
                          nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
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
                    DateFormat(
                      'dd/MM/yyyy – HH:mm',
                    ).format(DateTime.parse(c['created_at'])),
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color.fromARGB(255, 216, 216, 216),
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
                      : _buildContentWithMentions(c['content'], isRoot: true),
                  const SizedBox(height: 8),
                  ...commentReplies.map((r) {
                    final isReplyOwner = r['user_id'] == currentUserId;
                    final isReplyEditing = editingCommentId == r['id'];
                    final nombreR = r['users']['name'] ?? 'Usuario';
                    final colorR = Colors
                        .primaries[nombreR.hashCode % Colors.primaries.length];
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 37, 37, 37)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  nombreR,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: colorR,
                                  ),
                                ),
                                if (isReplyOwner)
                                  Row(
                                    children: [
                                      if (!isReplyEditing)
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
                                      if (isReplyEditing)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _updateComment(r['id']),
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _confirmDelete(r['id']),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
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
        }),
        const Divider(height: 18),
Container(
  decoration: BoxDecoration(
    color: const Color.fromARGB(255, 206, 206, 206),
    borderRadius: BorderRadius.circular(8),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: TextField(
    controller: commentController,
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
      labelText: 'Escribe un comentario',
      labelStyle: TextStyle(color: Color.fromARGB(255, 22, 22, 22)),
      border: InputBorder.none,
    ),
  ),
),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _addComment(),
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
    );
  }
}
