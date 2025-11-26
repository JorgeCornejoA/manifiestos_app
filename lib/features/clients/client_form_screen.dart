// lib/features/clients/client_form_screen.dart
import 'package:flutter/material.dart';
import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/services/supabase_service.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? client; // Cliente a editar (null si es nuevo)
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _ciudadController = TextEditingController();
  
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // Si estamos editando, llenamos los campos
      _nameController.text = widget.client!.name;
      _domicilioController.text = widget.client!.domicilio;
      _ciudadController.text = widget.client!.ciudad;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domicilioController.dispose();
    _ciudadController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return; // Validación falló
    }

    setState(() => _isLoading = true);

    try {
      final newClient = Client(
        id: widget.client?.id, // Mantenemos el ID si estamos editando
        name: _nameController.text,
        domicilio: _domicilioController.text,
        ciudad: _ciudadController.text,
      );

      if (_isEditing) {
        await _supabaseService.updateClient(newClient);
      } else {
        await _supabaseService.createClient(newClient);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cliente guardado con éxito')),
        );
        Navigator.of(context).pop(); // Volver a la lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
      ),
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
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _domicilioController,
                    decoration: const InputDecoration(labelText: 'Domicilio'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ciudadController,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveForm,
                    child: Text('Guardar Cliente'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}