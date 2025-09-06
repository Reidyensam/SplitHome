import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  List<Map<String, dynamic>> balances = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('balances')
        .select('from_user_id, to_user_id, amount, users_from:name, users_to:name')
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId');

    setState(() {
      balances = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balances del grupo'),
        backgroundColor: AppColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : balances.isEmpty
              ? const Center(child: Text('No hay balances registrados'))
              : ListView.builder(
                  itemCount: balances.length,
                  itemBuilder: (context, index) {
                    final balance = balances[index];
                    final from = balance['users_from']['name'] ?? 'Alguien';
                    final to = balance['users_to']['name'] ?? 'Alguien';
                    final amount = balance['amount'];

                    return Card(
                      child: ListTile(
                        title: Text('$from → $to'),
                        subtitle: Text('Bs. ${amount.toStringAsFixed(2)}'),
                        trailing: const Icon(Icons.swap_horiz),
                      ),
                    );
                  },
                ),
    );
  }
}