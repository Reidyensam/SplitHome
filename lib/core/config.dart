import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://nftdzpblovbwhwuporki.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mdGR6cGJsb3Zid2h3dXBvcmtpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNjY4MjQsImV4cCI6MjA3MTc0MjgyNH0.cZfxjYXxihhAApNbUXJdaanx4xwiNuZI6P661gOwpdI';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}