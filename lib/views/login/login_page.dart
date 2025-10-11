import 'package:flutter/material.dart';
import 'package:splithome/views/dashboard/widgets/dashboard_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final auth = AuthService();
      final response = await auth.signIn(email, password);

      if (!mounted) return;

      if (response != null && response.session != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final userData = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single();

        final role = userData['role'];

        final route = role == 'super_admin'
            ? '/super_admin_panel'
            : '/dashboard';

        Navigator.pushReplacementNamed(context, route);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Credenciales inválidas o error de conexión'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'SplitHome',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Ingresa tu correo' : null,
                    onChanged: (value) => email = value,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (value) =>
                        value!.length < 6 ? 'Mínimo 6 caracteres' : null,
                    onChanged: (value) => password = value,
                  ),
                  const SizedBox(height: 32),
                  DashboardActionButton(
                    label: 'Iniciar sesión',
                    icon: Icons.login,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}