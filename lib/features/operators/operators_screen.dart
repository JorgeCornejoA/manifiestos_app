// lib/features/operators/operators_screen.dart
import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class OperatorsScreen extends StatefulWidget {
  const OperatorsScreen({super.key});

  @override
  State<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends State<OperatorsScreen> {
  final _supabaseService = SupabaseService();
  late Future<List<Operator>> _operatorsFuture;

  @override
  void initState() {
    super.initState();
    _refreshOperators();
  }

  void _refreshOperators() {
    setState(() {
      _operatorsFuture = _supabaseService.getOperators();
    });
  }

  Future<void> _navigateToForm([Operator? operator]) async {
    await Navigator.of(context).pushNamed('/operator-form', arguments: operator);
    _refreshOperators();
  }

  Future<void> _deleteOperator(Operator operator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Operador'),
        content: Text('¿Eliminar a ${operator.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed == true && operator.id != null) {
      await _supabaseService.deleteOperator(operator.id!);
      _refreshOperators();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Operadores')),
      body: FutureBuilder<List<Operator>>(
        future: _operatorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final operators = snapshot.data;
          if (operators == null || operators.isEmpty) {
            return const Center(child: Text('No hay operadores registrados.'));
          }

          return ListView.builder(
            itemCount: operators.length,
            itemBuilder: (context, index) {
              final op = operators[index];
              return ListTile(
                title: Text(op.name),
                subtitle: Text('${op.trailer} - ${op.placas}'),
                onTap: () => _navigateToForm(op),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteOperator(op),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}