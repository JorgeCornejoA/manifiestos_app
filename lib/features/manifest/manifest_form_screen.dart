import 'package:flutter/material.dart';
import 'dart:typed_data'; 
import 'package:http/http.dart' as http; 
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manifiestos_app/models/manifest_data.dart';
import 'package:manifiestos_app/services/supabase_service.dart';
import 'package:manifiestos_app/utils/pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';

import 'package:manifiestos_app/models/client.dart';
import 'package:manifiestos_app/models/operator.dart';
import 'package:manifiestos_app/models/employee.dart';
import 'package:manifiestos_app/models/producer.dart';
import 'package:manifiestos_app/models/company_trailer.dart';

class _CargaItemControllers {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController producto;
  final TextEditingController etiquetas;
  final TextEditingController tamano;
  final TextEditingController pallets;
  final TextEditingController cajasPorPallet;
  final TextEditingController cajas;

  final FocusNode productoNode;
  final FocusNode etiquetasNode;
  final FocusNode tamanoNode;
  final FocusNode palletsNode;
  final FocusNode cajasPorPalletNode;

  _CargaItemControllers(CargaItem item)
      : producto = TextEditingController(text: item.producto),
        etiquetas = TextEditingController(text: item.etiquetas),
        tamano = TextEditingController(text: item.tamano),
        pallets = TextEditingController(text: item.pallets.toString()),
        cajasPorPallet = TextEditingController(text: item.cajasPorPallet.toString()),
        cajas = TextEditingController(text: (item.pallets * item.cajasPorPallet).toString()),
        productoNode = FocusNode(),
        etiquetasNode = FocusNode(),
        tamanoNode = FocusNode(),
        palletsNode = FocusNode(),
        cajasPorPalletNode = FocusNode();

  void dispose() {
    producto.dispose();
    etiquetas.dispose();
    tamano.dispose();
    pallets.dispose();
    cajasPorPallet.dispose();
    cajas.dispose();
    productoNode.dispose();
    etiquetasNode.dispose();
    tamanoNode.dispose();
    palletsNode.dispose();
    cajasPorPalletNode.dispose();
  }
}

class ManifestFormScreen extends StatefulWidget {
  final ManifestData? manifest;
  const ManifestFormScreen({super.key, this.manifest});

  @override
  State<ManifestFormScreen> createState() => _ManifestFormScreenState();
}

class _ManifestFormScreenState extends State<ManifestFormScreen> {
  int _currentStep = 0;
  final int _totalSteps = 8; 
  
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _canPop = false;

  Client? _selectedClient;
  Operator? _selectedOperator;

  String? _embarcoFirmaUrl;
  String? _recibioFirmaUrl;

  List<Uint8List> _evidencePhotos = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  final TextEditingController _bulkTextController = TextEditingController();

  String _selectedTipo = 'T'; 
  bool _showTrailerSelector = false; 

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep4 = GlobalKey<FormState>(); 
  final _formKeyStep5 = GlobalKey<FormState>(); 

  final _trailerNoController = TextEditingController();
  List<TextEditingController> _producerControllers = []; 
  final _fechaController = TextEditingController();
  
  final _consignadoAController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _condicionesController = TextEditingController();
  
  final _operadorController = TextEditingController();
  final _trailerController = TextEditingController();
  final _placasController = TextEditingController();
  final _cajaController = TextEditingController();
  final _lineaTransportistaController = TextEditingController();
  final _telController = TextEditingController();
  final _importeFleteController = TextEditingController();
  final _anticipoFleteController = TextEditingController();
  
  final _observacionesController = TextEditingController();
  final _embarcoNombreController = TextEditingController();
  final _recibioNombreController = TextEditingController();

  List<List<_CargaItemControllers>> _cargaSectionsControllers = [];
  
  late Map<int, TextEditingController> _trailerLayoutControllers;
  final SignatureController _embarcoSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _recibioSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  int _totalPallets = 0;
  int _totalCajas = 0;

  @override
  void initState() {
    super.initState();
    _trailerLayoutControllers = {
      for (var i = 0; i < 30; i++) i: TextEditingController()
    };
    if (widget.manifest != null) {
      _loadManifestData(widget.manifest!);
    } else {
      _fechaController.text = _formatDate(DateTime.now());
      setState(() {
        _addProducerSection(); 
      });
      _loadCurrentEmployee(); 
    }
  }

  Future<void> _loadCurrentEmployee() async {
    final emp = await _supabaseService.getCurrentEmployee();
    if (emp != null && mounted) {
      setState(() {
        _embarcoNombreController.text = emp.name;
        if (emp.signatureUrl != null) {
          _embarcoFirmaUrl = emp.signatureUrl;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd-MMM-yyyy', 'es_ES').format(date).toUpperCase();
    } catch (e) {
      const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      return '$day-$month-$year';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = _formatDate(picked);
      });
    }
  }

  void _addProducerSection() {
    setState(() {
      _producerControllers.add(TextEditingController());
      _cargaSectionsControllers.add([]); 
      _addItemToSection(_cargaSectionsControllers.length - 1);
    });
  }

  void _removeProducerSection(int index) {
    setState(() {
      _producerControllers[index].dispose();
      _producerControllers.removeAt(index);
      for (var controller in _cargaSectionsControllers[index]) {
        controller.dispose();
      }
      _cargaSectionsControllers.removeAt(index);
      _calculateTotals();
    });
  }

  void _addItemToSection(int sectionIndex) {
    final newControllers = _CargaItemControllers(CargaItem());
    newControllers.pallets.addListener(_calculateTotals);
    newControllers.cajasPorPallet.addListener(_calculateTotals);
    setState(() {
      while (_cargaSectionsControllers.length <= sectionIndex) {
        _cargaSectionsControllers.add([]);
      }
      _cargaSectionsControllers[sectionIndex].add(newControllers);
    });
  }

  void _removeItemFromSection(int sectionIndex, int itemIndex) {
    setState(() {
      _cargaSectionsControllers[sectionIndex][itemIndex].dispose();
      _cargaSectionsControllers[sectionIndex].removeAt(itemIndex);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    int currentTotalPallets = 0;
    int currentTotalCajas = 0;

    for (var section in _cargaSectionsControllers) {
      for (var controllers in section) {
        final pallets = int.tryParse(controllers.pallets.text) ?? 0;
        final cajasPorPallet = int.tryParse(controllers.cajasPorPallet.text) ?? 0;
        final cajas = pallets * cajasPorPallet;

        controllers.cajas.text = cajas.toString();
        currentTotalPallets += pallets;
        currentTotalCajas += cajas;
      }
    }

    if (mounted) {
      setState(() {
        _totalPallets = currentTotalPallets;
        _totalCajas = currentTotalCajas;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, 
        maxWidth: 1200,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _evidencePhotos.add(bytes);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error al seleccionar imagen: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _evidencePhotos.removeAt(index);
    });
  }

  void _loadManifestData(ManifestData manifest) async { 
    _selectedTipo = manifest.tipo;
    _trailerNoController.text = manifest.trailerNo;
    _fechaController.text = manifest.fecha;
    _consignadoAController.text = manifest.consignadoA;
    _domicilioController.text = manifest.domicilio;
    _ciudadController.text = manifest.ciudad;
    _condicionesController.text = manifest.condiciones;
    _operadorController.text = manifest.operador;
    _trailerController.text = manifest.trailer;
    _placasController.text = manifest.placas;
    _cajaController.text = manifest.caja;
    _lineaTransportistaController.text = manifest.lineaTransportista;
    _telController.text = manifest.tel;
    _importeFleteController.text = manifest.importeFlete.toString();
    _anticipoFleteController.text = manifest.anticipoFlete.toString();
    _observacionesController.text = manifest.observaciones;
    _embarcoNombreController.text = manifest.embarcoNombre;
    _recibioNombreController.text = manifest.recibioNombre;

    _embarcoFirmaUrl = manifest.embarcoFirmaUrl;
    _recibioFirmaUrl = manifest.recibioFirmaUrl;

    if (manifest.evidencePhotosUrls != null) {
      List<Uint8List> loadedPhotos = [];
      for (String url in manifest.evidencePhotosUrls!) {
        final bytes = await _downloadBytesFromUrl(url);
        if (bytes != null) loadedPhotos.add(bytes);
      }
      if (mounted) {
        setState(() {
          _evidencePhotos = loadedPhotos;
        });
      }
    }

    if (mounted) {
      setState(() {
        for (var controller in _producerControllers) controller.dispose();
        _producerControllers.clear();
        for (var section in _cargaSectionsControllers) {
          for (var controller in section) controller.dispose();
        }
        _cargaSectionsControllers.clear();

        List<String> producersList = manifest.sectionProducers;
        if (producersList.isEmpty && manifest.productor.isNotEmpty) {
           producersList = [manifest.productor];
        } else if (producersList.isEmpty) {
           producersList = ['']; 
        }

        for (String pName in producersList) {
          _producerControllers.add(TextEditingController(text: pName));
        }

        while (_cargaSectionsControllers.length < producersList.length) {
           _cargaSectionsControllers.add([]);
        }

        int sectionIndex = 0;
        for (var sectionData in manifest.carga) {
          if (sectionIndex >= _cargaSectionsControllers.length) {
             _cargaSectionsControllers.add([]);
          }
          List<_CargaItemControllers> sectionControllers = [];
          for (var item in sectionData) {
            final newControllers = _CargaItemControllers(item);
            newControllers.pallets.addListener(_calculateTotals);
            newControllers.cajasPorPallet.addListener(_calculateTotals);
            sectionControllers.add(newControllers);
          }
          _cargaSectionsControllers[sectionIndex] = sectionControllers;
          sectionIndex++;
        }

        if (_producerControllers.isEmpty) {
          _addProducerSection();
        }

        for (final entry in manifest.trailerLayout.entries) {
          final index = int.tryParse(entry.key);
          if (index != null && _trailerLayoutControllers.containsKey(index)) {
            _trailerLayoutControllers[index]!.text = entry.value;
          }
        }
        _calculateTotals();
      });
    }
  }

  @override
  void dispose() {
    _trailerNoController.dispose();
    for (var c in _producerControllers) c.dispose();
    _fechaController.dispose();
    _consignadoAController.dispose();
    _domicilioController.dispose();
    _ciudadController.dispose();
    _condicionesController.dispose();
    _operadorController.dispose();
    _trailerController.dispose();
    _placasController.dispose();
    _cajaController.dispose();
    _lineaTransportistaController.dispose();
    _telController.dispose();
    _importeFleteController.dispose();
    _anticipoFleteController.dispose();
    _observacionesController.dispose();
    _embarcoNombreController.dispose();
    _recibioNombreController.dispose();
    _embarcoSignatureController.dispose();
    _recibioSignatureController.dispose();
    _trailerLayoutControllers.forEach((_, controller) => controller.dispose());
    _bulkTextController.dispose();
    for (var section in _cargaSectionsControllers) {
      for (var controller in section) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<Iterable<Client>> _searchClients(String query) async {
    if (query.isEmpty) return const Iterable.empty();
    try {
      final data = await _supabaseService.searchClients(query);
      return data.map((json) => Client.fromMap(json));
    } catch (e) {
      _showErrorSnackbar('Error al buscar clientes: $e');
      return const Iterable.empty();
    }
  }

  Future<Iterable<Operator>> _searchOperators(String query) async {
    if (query.isEmpty) return const Iterable.empty();
    try {
      final data = await _supabaseService.searchOperators(query);
      return data.map((json) => Operator.fromMap(json));
    } catch (e) {
      _showErrorSnackbar('Error al buscar operadores: $e');
      return const Iterable.empty();
    }
  }

  Future<Iterable<Employee>> _searchEmployees(String query) async {
    if (query.isEmpty) return const Iterable.empty();
    try {
      final data = await _supabaseService.searchEmployees(query);
      return data.map((json) => Employee.fromMap(json));
    } catch (e) {
      _showErrorSnackbar('Error al buscar empleados: $e');
      return const Iterable.empty();
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Si sales ahora, perderás los datos ingresados en este manifiesto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ?? false;
  }

  bool _validateAllSteps() {
    if (_trailerNoController.text.isEmpty || _fechaController.text.isEmpty) {
      _showErrorSnackbar('Error en "Info General": Faltan campos.');
      return false;
    }
    if (_producerControllers.isEmpty || _producerControllers.any((c) => c.text.isEmpty)) {
       _showErrorSnackbar('Error en "Info General": Falta nombre del productor.');
       return false;
    }
    if (_consignadoAController.text.isEmpty) {
      _showErrorSnackbar('Error en "Destino": Falta "Consignado A".');
      return false;
    }
    if (_operadorController.text.isEmpty) {
      _showErrorSnackbar('Error en "Transportista": Falta "Operador".');
      return false;
    }
    if (_cargaSectionsControllers.isEmpty) {
      _showErrorSnackbar('Error en "Carga": Debe haber carga.');
      return false;
    }
    for (int i = 0; i < _cargaSectionsControllers.length; i++) {
      if (_cargaSectionsControllers[i].isEmpty) {
        _showErrorSnackbar('Error en "Carga" (Sección ${i+1}): Vacía.');
        return false;
      }
      for (var controller in _cargaSectionsControllers[i]) {
        if (controller.producto.text.isEmpty ||
            (int.tryParse(controller.pallets.text) ?? 0) <= 0 ||
            (int.tryParse(controller.cajasPorPallet.text) ?? 0) <= 0) {
          _showErrorSnackbar('Error en "Carga": Datos inválidos.');
          return false;
        }
      }
    }
    if (_observacionesController.text.trim().isEmpty) {
      _showErrorSnackbar('Error en "Observaciones": El campo es obligatorio.');
      return false;
    }
    if (_embarcoNombreController.text.isEmpty || _recibioNombreController.text.isEmpty) {
       _showErrorSnackbar('Error en "Firmas": Faltan los nombres.');
       return false;
    }
    bool embarcoValid = _embarcoSignatureController.isNotEmpty || (_embarcoFirmaUrl != null && _embarcoFirmaUrl!.isNotEmpty);
    bool recibioValid = _recibioSignatureController.isNotEmpty || (_recibioFirmaUrl != null && _recibioFirmaUrl!.isNotEmpty);

    if (!embarcoValid || !recibioValid) {
      _showErrorSnackbar('Error en "Firmas": Faltan las firmas.');
      return false;
    }
    bool isDiagramValid = _trailerLayoutControllers.values.any((c) => c.text.isNotEmpty);
    if (!isDiagramValid) {
      _showErrorSnackbar('Error en "Diagrama": Indique al menos una posición.');
      return false;
    }
    return true;
  }

  void _onStepContinue() {
    final isLastStep = _currentStep == _totalSteps - 1;

    if (isLastStep) {
      if (_validateAllSteps()) {
        _generateAndSavePdf();
      }
    } else {
      bool isValidCurrent = false;
      if (_currentStep == 0) isValidCurrent = _formKeyStep0.currentState!.validate();
      else if (_currentStep == 1) isValidCurrent = _formKeyStep1.currentState!.validate();
      else if (_currentStep == 2) isValidCurrent = _formKeyStep2.currentState!.validate();
      else if (_currentStep == 3) {
        isValidCurrent = _cargaSectionsControllers.isNotEmpty && 
                         _cargaSectionsControllers.every((s) => s.isNotEmpty);
        if (!isValidCurrent) _showErrorSnackbar('Añada carga antes de continuar.');
      }
      else if (_currentStep == 4) isValidCurrent = _formKeyStep4.currentState!.validate(); 
      else if (_currentStep == 5) isValidCurrent = _formKeyStep5.currentState!.validate(); 
      else if (_currentStep == 6) isValidCurrent = true; 
      else if (_currentStep == 7) isValidCurrent = true; 
      
      if (isValidCurrent) {
        setState(() => _currentStep += 1);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<Uint8List?> _downloadBytesFromUrl(String url) async {
    try {
      // 1. Extraemos la ruta interna limpia desde la URL larga
      // Ej: https://.../manifests/signatures/123.png -> signatures/123.png
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('manifests');
      
      if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
        final internalPath = pathSegments.sublist(bucketIndex + 1).join('/');
        
        // 2. Descargamos usando el cliente oficial de Supabase en lugar de 'http'
        final bytes = await Supabase.instance.client.storage
            .from('manifests')
            .download(internalPath);
            
        return bytes;
      }
      return null;
    } catch (e) {
      debugPrint('Excepción al descargar imagen con Supabase: $e');
      return null;
    }
  }

  Future<void> _generateAndSavePdf() async {
    setState(() => _isLoading = true);
    try {
      Uint8List? pdfEmbarcoBytes;
      Uint8List? pdfRecibioBytes;
      Uint8List? bdEmbarcoBytes;
      Uint8List? bdRecibioBytes;

      if (_embarcoSignatureController.isNotEmpty) {
        final bytes = await _embarcoSignatureController.toPngBytes();
        pdfEmbarcoBytes = bytes;
        bdEmbarcoBytes = bytes; 
      } else if (_embarcoFirmaUrl != null && _embarcoFirmaUrl!.isNotEmpty) {
        pdfEmbarcoBytes = await _downloadBytesFromUrl(_embarcoFirmaUrl!);
        bdEmbarcoBytes = null; 
      }

      if (_recibioSignatureController.isNotEmpty) {
        final bytes = await _recibioSignatureController.toPngBytes();
        pdfRecibioBytes = bytes;
        bdRecibioBytes = bytes;
      } else if (_recibioFirmaUrl != null && _recibioFirmaUrl!.isNotEmpty) {
        pdfRecibioBytes = await _downloadBytesFromUrl(_recibioFirmaUrl!);
        bdRecibioBytes = null;
      }

      final layoutMap = <String, String>{};
      _trailerLayoutControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) layoutMap[key.toString()] = controller.text;
      });

      final List<List<CargaItem>> cargaCompleta = _cargaSectionsControllers.map((section) {
        return section.map((controllers) {
          return CargaItem(
            producto: controllers.producto.text,
            etiquetas: controllers.etiquetas.text,
            tamano: controllers.tamano.text,
            pallets: int.tryParse(controllers.pallets.text) ?? 0,
            cajasPorPallet: int.tryParse(controllers.cajasPorPallet.text) ?? 0,
          );
        }).toList();
      }).toList();

      List<String> producerNames = _producerControllers.map((c) => c.text).toList();
      String mainProductorString = producerNames.join(" / ");

      final dataForBd = ManifestData(
        id: widget.manifest?.id,
        tipo: _selectedTipo, 
        trailerNo: _trailerNoController.text,
        productor: mainProductorString,
        fecha: _fechaController.text,
        consignadoA: _consignadoAController.text,
        domicilio: _domicilioController.text,
        ciudad: _ciudadController.text,
        condiciones: _condicionesController.text,
        operador: _operadorController.text,
        trailer: _trailerController.text,
        placas: _placasController.text,
        caja: _cajaController.text,
        lineaTransportista: _lineaTransportistaController.text,
        tel: _telController.text,
        importeFlete: int.tryParse(_importeFleteController.text) ?? 0,
        anticipoFlete: int.tryParse(_anticipoFleteController.text) ?? 0,
        carga: cargaCompleta,
        sectionProducers: producerNames,
        observaciones: _observacionesController.text,
        embarcoNombre: _embarcoNombreController.text,
        recibioNombre: _recibioNombreController.text,
        trailerLayout: layoutMap,
        embarcoFirmaBytes: bdEmbarcoBytes,
        recibioFirmaBytes: bdRecibioBytes,
        embarcoFirmaUrl: _embarcoFirmaUrl,
        recibioFirmaUrl: _recibioFirmaUrl,
        evidencePhotosBytes: _evidencePhotos, 
        evidencePhotosUrls: widget.manifest?.evidencePhotosUrls, 
      );

      final savedManifest = await _supabaseService.saveManifest(dataForBd);
      if (savedManifest == null) throw Exception("Error al guardar en BD.");

      final dataForPdf = ManifestData(
        id: savedManifest.id,
        folio: savedManifest.folio, 
        tipo: savedManifest.tipo,
        trailerNo: savedManifest.trailerNo,
        productor: savedManifest.productor,
        fecha: savedManifest.fecha,
        consignadoA: savedManifest.consignadoA,
        domicilio: savedManifest.domicilio,
        ciudad: savedManifest.ciudad,
        condiciones: savedManifest.condiciones,
        operador: savedManifest.operador,
        trailer: savedManifest.trailer,
        placas: savedManifest.placas,
        caja: savedManifest.caja,
        lineaTransportista: savedManifest.lineaTransportista,
        tel: savedManifest.tel,
        importeFlete: savedManifest.importeFlete,
        anticipoFlete: savedManifest.anticipoFlete,
        carga: savedManifest.carga,
        sectionProducers: savedManifest.sectionProducers,
        observaciones: savedManifest.observaciones,
        embarcoNombre: savedManifest.embarcoNombre,
        recibioNombre: savedManifest.recibioNombre,
        trailerLayout: savedManifest.trailerLayout,
        embarcoFirmaBytes: pdfEmbarcoBytes,
        recibioFirmaBytes: pdfRecibioBytes,
        evidencePhotosBytes: _evidencePhotos,
      );

      final pdfBytes = await PdfGenerator.generatePdfBytes(dataForPdf);
      final fileName = 'manifiesto-${savedManifest.id}.pdf';
      final pdfUrl = await _supabaseService.uploadPdf(pdfBytes, fileName);
      if (pdfUrl != null) {
        await _supabaseService.updatePdfUrl(savedManifest.id!, pdfUrl);
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Manifiesto guardado y PDF generado con éxito')));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) _showErrorSnackbar('Error al generar PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          setState(() {
            _canPop = true;
          });
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.manifest == null
              ? 'Nuevo Manifiesto'
              : 'Detalles del Manifiesto'),
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Guardar Manifiesto',
                onPressed: () {
                  if (_validateAllSteps()) {
                    _generateAndSavePdf();
                  }
                },
              ),
          ],
        ),
        body: Stepper(
          type: StepperType.vertical,
          physics: const ClampingScrollPhysics(),
          currentStep: _currentStep,
          onStepTapped: (int index) {
            setState(() {
              _currentStep = index;
            });
          },
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == _totalSteps - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: <Widget>[
                  if (_currentStep != 0)
                    Expanded(
                      child: TextButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('ATRÁS'),
                          onPressed: details.onStepCancel),
                    ),
                  if (_currentStep != 0) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                        icon: isLastStep
                            ? const Icon(Icons.save, size: 18)
                            : const Icon(Icons.arrow_forward, size: 18),
                        label: Text(isLastStep ? 'FINALIZAR' : 'SIGUIENTE'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: details.onStepContinue),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Info General'),
              content: Form(
                key: _formKeyStep0,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Tipo:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        ToggleButtons(
                          isSelected: [_selectedTipo == 'T', _selectedTipo == 'EA'],
                          onPressed: (index) {
                            setState(() {
                              _selectedTipo = index == 0 ? 'T' : 'EA';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: Colors.green,
                          constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
                          children: const [
                            Text("Trailer"),
                            Text("Entrada Alm."),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _trailerNoController,
                          decoration: InputDecoration(
                            labelText: _selectedTipo == 'T' ? 'TRAILER No.' : 'ENTRADA ALMACÉN No.',
                            hintText: '12345',
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _fechaController,
                          decoration: const InputDecoration(
                              labelText: 'FECHA', suffixIcon: Icon(Icons.calendar_today)),
                          readOnly: true,
                          onTap: _selectDate,
                          validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  const Align(
                    alignment: Alignment.centerLeft, 
                    child: Text("Productores", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                  ),
                  const SizedBox(height: 10),
                  
                  ...List.generate(_producerControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Autocomplete<Producer>(
                              optionsBuilder: (textEditingValue) async {
                                if (textEditingValue.text.isEmpty) return const Iterable.empty();
                                final data = await _supabaseService.searchProducers(textEditingValue.text);
                                return data.map((e) => Producer.fromMap(e));
                              },
                              displayStringForOption: (option) => option.name,
                              onSelected: (selection) {
                                _producerControllers[index].text = selection.name;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                                if (controller.text != _producerControllers[index].text) {
                                  controller.text = _producerControllers[index].text;
                                }
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'PRODUCTOR ${index + 1}',
                                    suffixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (val) => _producerControllers[index].text = val,
                                  validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                                );
                              },
                            ),
                          ),
                          if (_producerControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeProducerSection(index),
                            ),
                        ],
                      ),
                    );
                  }),

                  TextButton.icon(
                    icon: const Icon(Icons.add_circle),
                    label: const Text("Agregar otro Productor"),
                    onPressed: _addProducerSection,
                  ),
                ]),
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Destino'),
              content: Form(
                key: _formKeyStep1,
                child: Column(children: [
                  Autocomplete<Client>(
                    optionsBuilder: (textEditingValue) => _searchClients(textEditingValue.text),
                    displayStringForOption: (option) => option.name,
                    onSelected: (selection) {
                      setState(() {
                        _selectedClient = selection;
                        _consignadoAController.text = selection.name;
                        _domicilioController.text = selection.domicilio;
                        _ciudadController.text = selection.ciudad;
                      });
                      FocusScope.of(context).nextFocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (textEditingController.text != _consignadoAController.text) {
                          textEditingController.text = _consignadoAController.text;
                        }
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'CONSIGNADO A'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        onChanged: (value) {
                          _consignadoAController.text = value;
                          if (_selectedClient != null && value != _selectedClient!.name) {
                            setState(() {
                              _selectedClient = null;
                              _domicilioController.clear();
                              _ciudadController.clear();
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _domicilioController,
                      decoration: const InputDecoration(labelText: 'DOMICILIO'),
                      readOnly: _domicilioController.text.isNotEmpty && _consignadoAController.text.isNotEmpty,
                      textInputAction: TextInputAction.next),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                            controller: _ciudadController,
                            decoration: const InputDecoration(labelText: 'CIUDAD'),
                            readOnly: _ciudadController.text.isNotEmpty && _consignadoAController.text.isNotEmpty,
                            textInputAction: TextInputAction.next),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                            controller: _condicionesController,
                            decoration: const InputDecoration(labelText: 'CONDICIONES'),
                            textInputAction: TextInputAction.done),
                      ),
                    ],
                  ),
                ]),
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Transportista'),
              content: Form(
                key: _formKeyStep2,
                child: SingleChildScrollView(
                    child: Column(children: [
                  Autocomplete<Operator>(
                    optionsBuilder: (textEditingValue) => _searchOperators(textEditingValue.text),
                    displayStringForOption: (option) => option.name,
                    onSelected: (selection) {
                      setState(() {
                        _selectedOperator = selection;
                        _operadorController.text = selection.name;
                        _telController.text = selection.tel;
                        _recibioNombreController.text = selection.name;

                        if (selection.isLocal) {
                          _showTrailerSelector = true;
                          _trailerController.clear();
                          _placasController.clear();
                          _cajaController.clear();
                          _lineaTransportistaController.text = "FRUVER (PROPIO)";
                        } else {
                          _showTrailerSelector = false;
                          _trailerController.text = selection.trailer;
                          _placasController.text = selection.placas;
                          _cajaController.text = selection.caja;
                          _lineaTransportistaController.text = selection.lineaTransportista;
                        }
                      });
                      FocusScope.of(context).nextFocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (textEditingController.text != _operadorController.text) {
                          textEditingController.text = _operadorController.text;
                        }
                      });
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'OPERADOR'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        onChanged: (value) {
                          _operadorController.text = value;
                          if (_selectedOperator != null && value != _selectedOperator!.name) {
                            setState(() {
                              _selectedOperator = null;
                              _showTrailerSelector = false; 
                              _trailerController.clear();
                              _placasController.clear();
                              _cajaController.clear();
                              _lineaTransportistaController.clear();
                              _telController.clear();
                            });
                          }
                        },
                      );
                    },
                  ),
                  
                  if (_showTrailerSelector) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Seleccione el Trailer Local:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Autocomplete<CompanyTrailer>(
                            optionsBuilder: (textValue) => _supabaseService.searchCompanyTrailers(textValue.text),
                            displayStringForOption: (t) => t.name,
                            onSelected: (trailer) {
                              setState(() {
                                _trailerController.text = trailer.name;
                                _placasController.text = trailer.plate;
                                _cajaController.text = trailer.box;
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                               return TextField(
                                 controller: controller,
                                 focusNode: focusNode,
                                 decoration: const InputDecoration(
                                   hintText: 'Buscar trailer (ej: 01, T-20)...',
                                   icon: Icon(Icons.local_shipping)
                                 ),
                               );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                            controller: _trailerController,
                            decoration: const InputDecoration(labelText: 'TRAILER'),
                            textInputAction: TextInputAction.next),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                            controller: _placasController,
                            decoration: const InputDecoration(labelText: 'PLACAS'),
                            textInputAction: TextInputAction.next),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                            controller: _cajaController,
                            decoration: const InputDecoration(labelText: 'CAJA'),
                            textInputAction: TextInputAction.next),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                            controller: _lineaTransportistaController,
                            decoration: const InputDecoration(labelText: 'LINEA TRANSPORTISTA'),
                            textInputAction: TextInputAction.next),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                            controller: _telController,
                            decoration: const InputDecoration(labelText: 'TEL.'),
                            textInputAction: TextInputAction.next),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                            controller: _importeFleteController,
                            decoration: const InputDecoration(labelText: 'IMPORTE DEL FLETE'),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                            controller: _anticipoFleteController,
                            decoration: const InputDecoration(labelText: 'ANTICIPO DEL FLETE'),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next),
                      ),
                    ],
                  ),
                ])),
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Carga'),
              content: _buildCargaTable(),
              isActive: _currentStep >= 3,
            ),
            
            // --- NUEVO PASO: OBSERVACIONES ---
            Step(
              title: const Text('Observaciones'),
              content: Form(
                key: _formKeyStep4,
                child: TextFormField(
                  controller: _observacionesController,
                  decoration: const InputDecoration(labelText: 'OBSERVACIONES'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'El campo de observaciones es obligatorio' : null,
                ),
              ),
              isActive: _currentStep >= 4,
            ),
            
            Step(
              title: const Text('Firmas'),
              content: Form(
                key: _formKeyStep5,
                child: _buildSignatureSection()
              ),
              isActive: _currentStep >= 5,
            ),
            Step(
              title: const Text('Diagrama'),
              content: _buildTrailerDiagram(),
              isActive: _currentStep >= 6,
            ),
            Step(
              title: const Text('Evidencia'),
              content: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cámara'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_evidencePhotos.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _evidencePhotos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_evidencePhotos[index], fit: BoxFit.cover),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  color: Colors.red,
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    const Text('No hay fotos adjuntas.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              isActive: _currentStep >= 7, 
            ),
          ],
        ),
        floatingActionButton: _isLoading ? const CircularProgressIndicator() : null,
      ),
    );
  }

  Widget _buildCargaTable() {
    return Column(
      children: [
        for (int sectionIndex = 0; sectionIndex < _cargaSectionsControllers.length; sectionIndex++) ...[
          if (sectionIndex > 0) const Divider(thickness: 2, height: 40, color: Colors.blueGrey),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Carga: ${_producerControllers.length > sectionIndex ? _producerControllers[sectionIndex].text : "Productor ${sectionIndex + 1}"}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cargaSectionsControllers[sectionIndex].length,
            itemBuilder: (context, itemIndex) {
              final controllers = _cargaSectionsControllers[sectionIndex][itemIndex];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Form(
                    key: controllers.formKey,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Producto ${itemIndex + 1}',
                                style: Theme.of(context).textTheme.titleMedium),
                            if (_cargaSectionsControllers[sectionIndex].length > 1)
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItemFromSection(sectionIndex, itemIndex))
                          ],
                        ),
                        TextFormField(
                          controller: controllers.producto,
                          focusNode: controllers.productoNode,
                          decoration: const InputDecoration(labelText: 'Producto'),
                          onEditingComplete: () => controllers.etiquetasNode.requestFocus(),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        ),
                        TextFormField(
                            controller: controllers.etiquetas,
                            focusNode: controllers.etiquetasNode,
                            decoration: const InputDecoration(labelText: 'Etiquetas'),
                            onEditingComplete: () => controllers.tamanoNode.requestFocus(),
                            textInputAction: TextInputAction.next),
                        TextFormField(
                            controller: controllers.tamano,
                            focusNode: controllers.tamanoNode,
                            decoration: const InputDecoration(labelText: 'Tamaño'),
                            onEditingComplete: () => controllers.palletsNode.requestFocus(),
                            textInputAction: TextInputAction.next),
                        Row(
                          children: [
                            Expanded(
                                child: TextFormField(
                                    controller: controllers.pallets,
                                    focusNode: controllers.palletsNode,
                                    decoration: const InputDecoration(labelText: 'No. Pallets'),
                                    keyboardType: TextInputType.number,
                                    onEditingComplete: () => controllers.cajasPorPalletNode.requestFocus(),
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Obligatorio';
                                      if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser > 0';
                                      return null;
                                    })),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('x')),
                            Expanded(
                                child: TextFormField(
                                    controller: controllers.cajasPorPallet,
                                    focusNode: controllers.cajasPorPalletNode,
                                    decoration: const InputDecoration(labelText: 'Cajas x Pallet'),
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Obligatorio';
                                      if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser > 0';
                                      return null;
                                    })),
                          ],
                        ),
                        TextFormField(
                            controller: controllers.cajas,
                            decoration: const InputDecoration(labelText: 'Cajas (Total)'),
                            readOnly: true),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          Builder(builder: (context) {
            int sectionPallets = 0;
            int sectionCajas = 0;
            for (var controller in _cargaSectionsControllers[sectionIndex]) {
              int p = int.tryParse(controller.pallets.text) ?? 0;
              int cp = int.tryParse(controller.cajasPorPallet.text) ?? 0;
              sectionPallets += p;
              sectionCajas += (p * cp);
            }
            return Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Subtotal Carga ${sectionIndex + 1}: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(width: 10),
                  Text('$sectionPallets p.', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  Text('$sectionCajas c.', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),

          TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Añadir Producto'),
              onPressed: () => _addItemToSection(sectionIndex)),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSignaturePad(
              title: 'EMBARCÓ (Nombre y Firma)',
              nameController: _embarcoNombreController,
              signatureController: _embarcoSignatureController,
              existingUrl: _embarcoFirmaUrl,
              onClearUrl: () {
                setState(() {
                  _embarcoFirmaUrl = null;
                });
              },
              onEmployeeSelected: (employee) {
                setState(() {
                  _embarcoNombreController.text = employee.name;
                  if (employee.signatureUrl != null) {
                    _embarcoFirmaUrl = employee.signatureUrl;
                    _embarcoSignatureController.clear(); 
                  }
                });
              }
          ),
          const SizedBox(height: 24),
          _buildSignaturePad(
              title: 'RECIBIÓ (NOMBRE y FIRMA)',
              nameController: _recibioNombreController,
              signatureController: _recibioSignatureController,
              existingUrl: _recibioFirmaUrl,
              onClearUrl: () {
                setState(() {
                  _recibioFirmaUrl = null;
                });
              },
              onEmployeeSelected: null 
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePad({
    required String title,
    required TextEditingController nameController,
    required SignatureController signatureController,
    String? existingUrl,
    VoidCallback? onClearUrl,
    Function(Employee)? onEmployeeSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8)),
          height: 150,
          width: double.infinity,
          child: existingUrl != null && existingUrl.isNotEmpty
              ? Stack(
                  children: [
                    Center(
                      child: Image.network(
                        existingUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        color: Colors.white.withOpacity(0.7),
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Firmar de nuevo"),
                          onPressed: onClearUrl,
                        ),
                      ),
                    )
                  ],
                )
              : Signature(
                  controller: signatureController,
                  height: 150,
                  backgroundColor: Colors.grey[200]!),
        ),
        if (existingUrl == null || existingUrl.isEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: () => signatureController.undo()),
              IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: () => signatureController.redo()),
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => signatureController.clear()),
            ],
          ),
        
        if (onEmployeeSelected != null)
          Autocomplete<Employee>(
            optionsBuilder: (textEditingValue) => _searchEmployees(textEditingValue.text),
            displayStringForOption: (option) => option.name,
            onSelected: (selection) {
              onEmployeeSelected(selection);
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (textEditingController.text != nameController.text) {
                  textEditingController.text = nameController.text;
                }
              });
              
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
                onChanged: (val) {
                  nameController.text = val;
                },
              );
            },
          )
        else
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'El nombre es obligatorio';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildTrailerDiagram() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          _selectedIndices.clear(); 
                          _bulkTextController.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSelectionMode ? Colors.green : Colors.grey[300],
                        foregroundColor: _isSelectionMode ? Colors.white : Colors.black,
                      ),
                      icon: Icon(_isSelectionMode ? Icons.check_box : Icons.check_box_outline_blank),
                      label: Text(_isSelectionMode ? 'Terminar Selección' : 'Activar Selección Múltiple'),
                    ),
                  ),
                ],
              ),
              
              if (_isSelectionMode) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.length == 30) {
                            _selectedIndices.clear();
                          } else {
                            for (int i = 0; i < 30; i++) _selectedIndices.add(i);
                          }
                        });
                      },
                      child: Text(_selectedIndices.length == 30 ? 'Deseleccionar Todo' : 'Seleccionar Todo'),
                    ),
                    const Spacer(),
                    Text('${_selectedIndices.length} seleccionados', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bulkTextController,
                        decoration: const InputDecoration(
                          labelText: 'Texto para aplicar',
                          hintText: 'Ej. TOMATE',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _selectedIndices.isEmpty ? null : () {
                        setState(() {
                          for (int index in _selectedIndices) {
                            _trailerLayoutControllers[index]?.text = _bulkTextController.text;
                          }
                          
                          // --- LA MEJORA: LIMPIAR AL APLICAR ---
                          _selectedIndices.clear();
                          _bulkTextController.clear();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Texto aplicado a las casillas seleccionadas'), duration: Duration(seconds: 1)),
                          );
                        });
                      },
                      child: const Text('APLICAR'),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 1),
              ],
            ],
          ),
        ),

        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text('DIFUSOR'), Text('PUERTAS')]),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4),
          itemCount: 30,
          itemBuilder: (context, index) {
            final isSelected = _selectedIndices.contains(index);
            final controller = _trailerLayoutControllers[index];

            if (_isSelectionMode) {
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIndices.remove(index);
                    } else {
                      _selectedIndices.add(index);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade100 : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${index + 1}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      if (controller!.text.isNotEmpty)
                        Text(controller.text, 
                          style: const TextStyle(fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              );
            }

            return TextFormField(
                controller: controller,
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: '${index + 1}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8) 
                ),
                textAlign: TextAlign.center);
          },
        ),
      ],
    );
  }
}