import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // Manejar error si es necesario
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        children: [
          _MenuButton(
            icon: Icons.description,
            label: 'Llenar Formato',
            onPressed: () {
              Navigator.of(context).pushNamed('/manifest-form');
            },
          ),
          _MenuButton(
            icon: Icons.list_alt,
            label: 'Consultar Manifiestos',
            onPressed: () {
              Navigator.of(context).pushNamed('/manifests-list');
            },
          ),
          _MenuButton(
            icon: Icons.people,
            label: 'Clientes',
            onPressed: () {
              Navigator.of(context).pushNamed('/clients');
            },
          ),
          _MenuButton(
            icon: Icons.local_shipping,
            label: 'Operadores',
            onPressed: () {
              Navigator.of(context).pushNamed('/operators');            },
          ),
          _MenuButton(
            icon: Icons.badge,
            label: 'Empleados',
            onPressed: () {
              // TODO: Crear y navegar a la pantalla de Empleados
            },
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

