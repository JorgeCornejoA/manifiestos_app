import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manifiestos_app/models/product.dart';
import 'package:manifiestos_app/models/tamano.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Product> _products = [];
  List<Tamano> _tamanos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final productsData = await _supabaseService.getAllProducts();
      final tamanosData = await _supabaseService.getTamanos();
      if (mounted) {
        setState(() {
          _products = productsData;
          _tamanos = tamanosData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProductDialog([Product? product]) {
    final isEditing = product != null;
    final codigoController = TextEditingController(text: product?.codigoPro);
    final nombreController = TextEditingController(text: product?.nombrePro);
    String? selectedTamano = product?.codigoTam;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codigoController,
                  enabled: !isEditing, // El código no se edita si ya existe
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Código del Producto (SKU)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nombreController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Tamaño asociado'),
                  value: selectedTamano,
                  items: _tamanos.map((t) {
                    return DropdownMenuItem(
                      value: t.codigoTam,
                      child: Text(t.nombreTam),
                    );
                  }).toList(),
                  onChanged: (val) => selectedTamano = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codigoController.text.isEmpty || nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código y Nombre son obligatorios')),
                  );
                  return;
                }

                final newProduct = Product(
                  codigoPro: codigoController.text.toUpperCase(),
                  nombrePro: nombreController.text.toUpperCase(),
                  codigoTam: selectedTamano,
                );

                Navigator.pop(context);
                setState(() => _isLoading = true);

                try {
                  if (isEditing) {
                    await _supabaseService.updateProduct(newProduct);
                  } else {
                    await _supabaseService.createProduct(newProduct);
                  }
                  await _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(String codigoPro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro de eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Eliminar')
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _supabaseService.deleteProduct(codigoPro);
        await _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final prod = _products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.inventory_2, color: Colors.blue),
                ),
                title: Text(prod.nombrePro, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Cód: ${prod.codigoPro} | Tamaño: ${prod.nombreTam.isNotEmpty ? prod.nombreTam : "N/A"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showProductDialog(prod),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProduct(prod.codigoPro),
                    ),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}