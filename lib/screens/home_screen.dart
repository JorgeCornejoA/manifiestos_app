import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importa tus pantallas
import 'package:manifiestos_app/features/employees/employees_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // Manejar error
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _MenuItem(
        title: 'Nuevo Manifiesto',
        icon: Icons.add_circle_outline,
        color: const Color(0xFF2E7D32),
        route: '/manifest-form',
      ),
      _MenuItem(
        title: 'Consultar',
        icon: Icons.search,
        color: const Color(0xFF00897B),
        route: '/manifests-list',
      ),
      _MenuItem(
        title: 'Clientes',
        icon: Icons.business,
        color: const Color(0xFF558B2F),
        route: '/clients',
      ),
      _MenuItem(
        title: 'Operadores',
        icon: Icons.local_shipping,
        color: const Color(0xFF388E3C),
        route: '/operators',
      ),
      _MenuItem(
        title: 'Empleados',
        icon: Icons.badge,
        color: const Color(0xFF43A047),
        isDirectNav: true,
        destination: const EmployeesScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // --- ENCABEZADO CORREGIDO (A prueba de Overflow) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. EL LOGO (Izquierda)
                  // Usamos Flexible para que si el logo es muy ancho, se adapte
                  // y no empuje al botón fuera de la pantalla.
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(2), // Un pequeño margen interno
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ]
                      ),
                      // Alineamos a la izquierda por si el Flexible deja espacio libre
                      alignment: Alignment.centerLeft, 
                      child: Image.asset(
                        'assets/images/logo.png', 
                        height: 50, // Reduje un poco la altura para seguridad
                        fit: BoxFit.contain, // Asegura que se vea completo
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 15), // Espacio de seguridad entre Logo y Botón

                  // 2. BOTÓN CERRAR SESIÓN (Derecha)
                  // Este mantiene su tamaño fijo
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _signOut(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ]
                        ),
                        child: const Icon(Icons.logout, color: Colors.grey, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
              // ---------------------------------------------------

              const SizedBox(height: 20), 

              // --- GRILLA DE BOTONES ---
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final availableWidth = constraints.maxWidth;
                    
                    final itemHeight = (availableHeight - 20) / 3; 
                    final itemWidth = availableWidth / 2; 
                    
                    final aspectRatio = itemWidth / itemHeight;

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        return _DashboardCard(item: menuItems[index]);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  final bool isDirectNav;
  final Widget? destination;

  _MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
    this.isDirectNav = false,
    this.destination,
  });
}

class _DashboardCard extends StatelessWidget {
  final _MenuItem item;

  const _DashboardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (item.isDirectNav && item.destination != null) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => item.destination!),
              );
            } else if (item.route != null) {
              Navigator.of(context).pushNamed(item.route!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0), // Padding interno de la tarjeta
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 36, // Icono ligeramente ajustado
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}