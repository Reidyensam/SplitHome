import 'package:flutter/material.dart';
import 'package:splithome/views/balances/balance_page.dart';
import 'package:splithome/views/super_admin/super_admin_panel.dart';
import 'package:splithome/views/groups/edit_group_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splithome/core/constants.dart';
import 'package:splithome/views/login/login_page.dart';
import 'package:splithome/views/login/register_page.dart';
import 'package:splithome/views/dashboard/dashboard_page.dart';
import 'package:splithome/views/groups/group_detail_page.dart';
import 'package:splithome/views/super_admin/promote_user_page.dart';
import 'package:splithome/views/groups/group_setup_page.dart';
import 'package:splithome/views/notifications/notification_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nftdzpblovbwhwuporki.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mdGR6cGJsb3Zid2h3dXBvcmtpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNjY4MjQsImV4cCI6MjA3MTc0MjgyNH0.cZfxjYXxihhAApNbUXJdaanx4xwiNuZI6P661gOwpdI',
  );

  runApp(const SplitHomeApp());
}

class SplitHomeApp extends StatelessWidget {
  const SplitHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitHome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        cardColor: AppColors.card,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
        ),
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          error: AppColors.error,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/notificaciones': (context) => const NotificationPage(),
        '/register': (context) => const RegisterPage(),
        '/promote_user': (context) => const PromoteUserPage(),
        '/crearGrupo': (context) => const GroupSetupPage(),
        '/super_admin_panel': (context) => const SuperAdminPanel(),
        '/balances': (context) => const BalancePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/group_detail_page') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => GroupDetailPage(
              groupId: args['groupId'] as String,
              groupName: args['groupName'] as String,
            ),
          );
        }

        if (settings.name == '/edit_group_page') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => EditGroupPage(
              groupId: args['groupId'],
              groupName: args['groupName'],
            ),
          );
        }

        return null;
      },
    );
  }
}
