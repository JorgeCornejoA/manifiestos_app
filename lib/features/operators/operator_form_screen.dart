// lib/features/operators/operator_form_screen.dart
import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class OperatorFormScreen extends StatefulWidget {
  final Operator? operator;
  const OperatorFormScreen({super.key, this.operator});

  @override
  State<OperatorFormScreen> createState() => _OperatorFormScreenState();
}

class _OperatorFormScreenState extends State<OperatorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  // Controladores para todos los campos del operador
  final _nameController = TextEditingController();
  final _trailerController = TextEditingController();
  final _placasController = TextEditingController();
  final _cajaController = TextEditingController();
  final _lineaController = TextEditingController();
  final _telController = TextEditingController();

  bool get _isEditing => widget.operator != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.operator!.name;
      _trailerController.text = widget.operator!.trailer;
      _placasController.text = widget.operator!.placas;
      _cajaController.text = widget.operator!.caja;
      _lineaController.text = widget.operator!.lineaTransportista;
      _telController.text = widget.operator!.tel;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _trailerController.dispose();
    _placasController.dispose();
    _cajaController.dispose();
    _lineaController.dispose();
    _telController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newOperator = Operator(
        id: widget.operator?.id,
        name: _nameController.text,
        trailer: _trailerController.text,
        placas: _placasController.text,
        caja: _cajaController.text,
        lineaTransportista: _lineaController.text,
        tel: _telController.text,
      );

      if (_isEditing) {
        await _supabaseService.updateOperator(newOperator);
      } else {
        await _supabaseService.createOperator(newOperator);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operador guardado con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar Operador' : 'Nuevo Operador')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _trailerController,
                          decoration: const InputDecoration(labelText: 'Trailer'),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _placasController,
                          decoration: const InputDecoration(labelText: 'Placas'),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cajaController,
                    decoration: const InputDecoration(labelText: 'Caja'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lineaController,
                    decoration: const InputDecoration(labelText: 'Línea Transportista'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telController,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveForm,
                    child: const Text('Guardar Operador'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}