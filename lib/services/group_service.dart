import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  Future<List<Map<String, dynamic>>> getGroupsForUser(String userId) async {
    final response = await Supabase.instance.client
        .from('group_members')
        .select('group_id, groups(name, type)')
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(response);
  }
}