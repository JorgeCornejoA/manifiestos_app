import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class OperatorsScreen extends StatefulWidget {
  const OperatorsScreen({super.key});

  @override
  State<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends State<OperatorsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Operator> _operators = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOperators();
  }

  Future<void> _loadOperators() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getOperators();
      setState(() {
        _operators = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cargar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOperator(Operator operator) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Operador'),
        content: Text('¿Seguro de eliminar a ${operator.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && operator.id != null) {
      try {
        await _supabaseService.deleteOperator(operator.id!);
        _loadOperators();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _showOperatorDialog({Operator? operator}) {
    final nameCtrl = TextEditingController(text: operator?.name ?? '');
    final trailerCtrl = TextEditingController(text: operator?.trailer ?? '');
    final placasCtrl = TextEditingController(text: operator?.placas ?? '');
    final cajaCtrl = TextEditingController(text: operator?.caja ?? '');
    final lineaCtrl = TextEditingController(text: operator?.lineaTransportista ?? '');
    final telCtrl = TextEditingController(text: operator?.tel ?? '');
    
    bool isLocal = operator?.isLocal ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(operator == null ? 'Nuevo Operador' : 'Editar Operador'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- SWITCH ---
                  Container(
                    decoration: BoxDecoration(
                      color: isLocal ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isLocal ? Colors.blue : Colors.grey.shade300)
                    ),
                    child: SwitchListTile(
                      title: const Text("¿Es Chofer Local / Flotilla?", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(isLocal 
                        ? "Usará trailers de la empresa" 
                        : "Usa su propio camión fijo"),
                      value: isLocal,
                      onChanged: (val) {
                        setStateDialog(() {
                          isLocal = val;
                          if (isLocal) {
                            // Limpiamos los campos al cambiar a local
                            trailerCtrl.clear();
                            placasCtrl.clear();
                            cajaCtrl.clear();
                            lineaCtrl.text = "FRUVER (PROPIO)";
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                  ),
                  const SizedBox(height: 10),
                  
                  const Divider(),

                  // --- AQUÍ ESTÁ LA MAGIA DEL TAMAÑO FIJO ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // CAPA 1: Los campos del vehículo (Invisibles pero ocupando espacio)
                      Visibility(
                        visible: !isLocal, // Solo visibles si NO es local
                        maintainSize: true, // ¡IMPORTANTE! Mantener tamaño
                        maintainAnimation: true,
                        maintainState: true,
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Datos del Vehículo Fijo", 
                                style: TextStyle(fontSize: 12, color: Colors.grey))
                            ),
                            Row(
                              children: [
                                Expanded(child: TextFormField(
                                  controller: trailerCtrl, 
                                  decoration: const InputDecoration(labelText: 'Trailer')
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: TextFormField(
                                  controller: placasCtrl, 
                                  decoration: const InputDecoration(labelText: 'Placas')
                                )),
                              ],
                            ),
                            TextFormField(
                              controller: cajaCtrl, 
                              decoration: const InputDecoration(labelText: 'Caja')
                            ),
                            TextFormField(
                              controller: lineaCtrl, 
                              decoration: const InputDecoration(labelText: 'Línea Transportista')
                            ),
                          ],
                        ),
                      ),

                      // CAPA 2: El mensaje de nota (Aparece en el espacio vacío)
                      if (isLocal)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.blue, size: 30),
                              SizedBox(height: 10),
                              Text(
                                "Los datos del vehículo se seleccionarán del inventario al crear el manifiesto.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // ----------------------------------------------------

                  const SizedBox(height: 10),
                  TextFormField(
                    controller: telCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  
                  final newOperator = Operator(
                    id: operator?.id,
                    name: nameCtrl.text,
                    trailer: trailerCtrl.text,
                    placas: placasCtrl.text,
                    caja: cajaCtrl.text,
                    lineaTransportista: lineaCtrl.text,
                    tel: telCtrl.text,
                    isLocal: isLocal,
                  );

                  try {
                    if (operator == null) {
                      await _supabaseService.createOperator(newOperator);
                    } else {
                      await _supabaseService.updateOperator(newOperator);
                    }
                    if (mounted) _loadOperators();
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    print(e);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operadores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _operators.isEmpty
              ? const Center(child: Text('No hay operadores registrados.'))
              : ListView.builder(
                  itemCount: _operators.length,
                  itemBuilder: (context, index) {
                    final op = _operators[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: op.isLocal ? Colors.blue.shade100 : Colors.grey.shade200,
                          child: Icon(
                            op.isLocal ? Icons.work : Icons.local_shipping,
                            color: op.isLocal ? Colors.blue : Colors.grey,
                          ),
                        ),
                        title: Text(op.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (op.isLocal)
                              const Text("Chofer Local / Flotilla", style: TextStyle(color: Colors.blue, fontSize: 12))
                            else
                              Text("${op.trailer} - ${op.lineaTransportista}"),
                            if (op.tel.isNotEmpty) Text("Tel: ${op.tel}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showOperatorDialog(operator: op),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteOperator(op),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOperatorDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}