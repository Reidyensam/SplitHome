import 'package:flutter/material.dart';
import '../views/login/login_page.dart';
import '../views/dashboard/dashboard_page.dart';
import '../views/login/register_page.dart';
import '../views/super_admin/promote_user_page.dart';
import '../views/expenses/edit_expense_page.dart';
import '../views/balances/balance_page.dart';
import '../views/super_admin/super_admin_panel.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/login': (context) => const LoginPage(),
    '/dashboard': (context) => const DashboardPage(),
    '/register': (context) => const RegisterPage(),
    '/super_admin': (context) => const SuperAdminPanel(),
    '/balances': (context) => const BalancePage(), 
  };
}
