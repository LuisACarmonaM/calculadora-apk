import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'services/dolar_api_service.dart';

void main() {
  runApp(const CalculadoraApp());
}

class CalculadoraApp extends StatelessWidget {
  const CalculadoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conversor Dólar/Euro',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const CalculadoraScreen(),
    );
  }
}

class FormatoMiles extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    int offsetFromEnd = newValue.text.length - newValue.selection.end;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

    if (','.allMatches(cleanText).length > 1) {
      cleanText = cleanText.substring(0, cleanText.lastIndexOf(','));
    }

    List<String> parts = cleanText.split(',');
    String integerPart = parts[0];

    String formattedInteger = '';
    for (int i = integerPart.length - 1, j = 1; i >= 0; i--, j++) {
      formattedInteger = integerPart[i] + formattedInteger;
      if (j % 3 == 0 && i != 0) {
        formattedInteger = '.$formattedInteger';
      }
    }

    String finalText = formattedInteger;
    if (parts.length > 1) {
      finalText += ',${parts[1]}';
    }

    int finalCursorPosition = finalText.length - offsetFromEnd;
    finalCursorPosition = finalCursorPosition.clamp(0, finalText.length);

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: finalCursorPosition),
    );
  }
}

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final DolarApiService _apiService = DolarApiService();

  double _tasaActual = 0.0;
  String _fechaActualizacion = '';
  bool _isLoading = true;

  // --- NUEVA VARIABLE DE CONTROL ---
  bool _esDolar = true;

  final TextEditingController _foreignController =
      TextEditingController(text: "1,00");
  final TextEditingController _bsController = TextEditingController();

  final NumberFormat _formatoInyeccion = NumberFormat("#,##0.00", "es_VE");
  final NumberFormat _formatoTasa =
      NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _cargarTasa();
  }

  // Modificado para pasar el estado actual de la moneda a la API
  Future<void> _cargarTasa() async {
    final data = await _apiService.getTasas(_esDolar);
    if (data != null && mounted) {
      setState(() {
        _tasaActual = (data['promedio'] ?? 0).toDouble();
        DateTime fecha = DateTime.parse(data['fechaActualizacion']);
        _fechaActualizacion = DateFormat('dd/MM/yyyy').format(fecha);
        _isLoading = false;

        _convertirDivisaABs(_foreignController.text);
      });
    }
  }

  // --- FUNCIÓN PARA CAMBIAR ENTRE DÓLAR Y EURO ---
  void _cambiarMoneda() {
    setState(() {
      _esDolar = !_esDolar;
      _isLoading = true;
    });
    _cargarTasa();
  }

  void _convertirDivisaABs(String valor) {
    if (_tasaActual == 0) return;
    if (valor.isEmpty) {
      _bsController.text = '';
      return;
    }

    String valorLimpio = valor.replaceAll('.', '').replaceAll(',', '.');
    double divisa = double.tryParse(valorLimpio) ?? 0.0;

    double bs = divisa * _tasaActual;
    _bsController.text = _formatoInyeccion.format(bs);
  }

  void _convertirBsADivisa(String valor) {
    if (_tasaActual == 0) return;
    if (valor.isEmpty) {
      _foreignController.text = '';
      return;
    }

    String valorLimpio = valor.replaceAll('.', '').replaceAll(',', '.');
    double bs = double.tryParse(valorLimpio) ?? 0.0;

    double divisa = bs / _tasaActual;
    _foreignController.text = _formatoInyeccion.format(divisa);
  }

  void _limpiarTodo() {
    _foreignController.text = "1,00";
    _convertirDivisaABs("1,00");
  }

  void _copiarAlPortapapeles(String texto) {
    if (texto.isEmpty) return;
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('¡Monto copiado!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('💱 Conversor BCV',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _limpiarTodo,
            tooltip: 'Restablecer',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // --- BANNER VERDE CONVERTIDO EN BOTÓN INTERACTIVO ---
                        InkWell(
                          onTap: _cambiarMoneda,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _esDolar
                                      ? 'Dólar BCV'
                                      : 'Euro BCV', // Cambia el texto automáticamente
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.loop,
                                    color: Colors.white,
                                    size: 20), // Icono indicador de cambio
                              ],
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // INPUT DE DIVISA EXTRANJERA (DÓLAR O EURO)
                              TextField(
                                controller: _foreignController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [FormatoMiles()],
                                onChanged: _convertirDivisaABs,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  prefixText: _esDolar
                                      ? '\$  '
                                      : '€  ', // Cambia el símbolo dinámicamente
                                  prefixStyle: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  hintText: "0,00",
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.green, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy,
                                        color: Colors.grey),
                                    onPressed: () => _copiarAlPortapapeles(
                                        _foreignController.text),
                                    tooltip: _esDolar
                                        ? 'Copiar Dólares'
                                        : 'Copiar Euros',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // INPUT DE BOLÍVARES
                              TextField(
                                controller: _bsController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [FormatoMiles()],
                                onChanged: _convertirBsADivisa,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  prefixText: 'Bs  ',
                                  prefixStyle: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  hintText: "0,00",
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.green, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy,
                                        color: Colors.grey),
                                    onPressed: () => _copiarAlPortapapeles(
                                        _bsController.text),
                                    tooltip: 'Copiar Bolívares',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16)),
                              border: Border(
                                  top:
                                      BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    _fechaActualizacion,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.arrow_upward,
                                      size: 16, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    // Cambia la leyenda del pie de página según corresponda
                                    _esDolar
                                        ? '1 USD = ${_formatoTasa.format(_tasaActual)}'
                                        : '1 EUR = ${_formatoTasa.format(_tasaActual)}',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _foreignController.dispose();
    _bsController.dispose();
    super.dispose();
  }
}
