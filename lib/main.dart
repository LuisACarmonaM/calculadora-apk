import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/dolar_api_service.dart';

void main() {
  runApp(const CalculadoraApp());
}

class CalculadoraApp extends StatelessWidget {
  const CalculadoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversor Dólar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CalculadoraScreen(),
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

  // Controladores de los inputs (Equivalente a document.getElementById)
  final TextEditingController _usdController = TextEditingController(text: "1");
  final TextEditingController _bsController = TextEditingController();

  // Variables para mostrar los resultados (Equivalente a los innerHTML de resultBs y resultUsd)
  double _resultadoBs = 0.0;
  double _resultadoUsd = 0.0;

  // Formateadores (Equivalente a tu función formatearNumero)
  final NumberFormat _formatoBs =
      NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ', decimalDigits: 2);
  final NumberFormat _formatoUsd =
      NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 4);

  @override
  void initState() {
    super.initState();
    _cargarTasa();
  }

  Future<void> _cargarTasa() async {
    final data = await _apiService.getTasas();
    if (data != null && mounted) {
      setState(() {
        _tasaActual = (data['promedio'] ?? 0).toDouble();
        // Formatear la fecha que viene de la API
        DateTime fecha = DateTime.parse(data['fechaActualizacion']);
        _fechaActualizacion = DateFormat('dd/MM/yyyy').format(fecha);
        _isLoading = false;
        _convertirUSDaBs(_usdController.text);
      });
    }
  }

  // Lógica de conversión (Equivalente a convertirUSDaBs en JS)
  void _convertirUSDaBs(String valor) {
    if (_tasaActual == 0) return;

    // Limpiamos el texto ingresado (cambiar coma por punto para el parseo en Dart)
    String valorLimpio = valor.replaceAll(',', '.');
    double usd = double.tryParse(valorLimpio) ?? 0.0;

    setState(() {
      _resultadoBs = usd * _tasaActual;
    });
  }

  // Lógica de conversión (Equivalente a convertirBsaUSD en JS)
  void _convertirBsaUSD(String valor) {
    if (_tasaActual == 0) return;

    String valorLimpio = valor.replaceAll(',', '.');
    double bs = double.tryParse(valorLimpio) ?? 0.0;

    setState(() {
      _resultadoUsd = bs / _tasaActual;
    });
  }

  // Equivalente a limpiarTodo()
  void _limpiarTodo() {
    setState(() {
      _usdController.text = "1";
      _bsController.clear();
      _convertirUSDaBs("1");
      _resultadoUsd = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💱 Conversor de Moneda'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- SECCIÓN USD A BS ---
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💰 USD (Dólares)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usdController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: _convertirUSDaBs,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "0.00",
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🇻🇪 Equivalente en Bolívares',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  _formatoBs.format(_resultadoBs),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- SECCIÓN BS A USD ---
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🇻🇪 Bs. (Bolívares)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bsController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: _convertirBsaUSD,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "0.00",
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💰 Equivalente en Dólares',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  _formatoUsd.format(_resultadoUsd),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- BOTÓN LIMPIAR ---
                  ElevatedButton.icon(
                    onPressed: _limpiarTodo,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Limpiar Todo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- INFO DE LA TASA ---
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '1 USD = ${_formatoBs.format(_tasaActual)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '📅 Actualizado: $_fechaActualizacion',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usdController.dispose();
    _bsController.dispose();
    super.dispose();
  }
}
