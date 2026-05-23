import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
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
      title: 'Conversor & Calculadora BCV',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.green,
          secondary: Colors.greenAccent,
          surface: Color(0xFF1E1E1E),
        ),
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
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
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
      if (j % 3 == 0 && i != 0) formattedInteger = '.$formattedInteger';
    }
    String finalText = formattedInteger;
    if (parts.length > 1) finalText += ',${parts[1]}';
    int finalCursorPosition =
        (finalText.length - offsetFromEnd).clamp(0, finalText.length);
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

enum ModoVista { dolar, euro, personalizada, calculadora }

// --- NUEVO: ENUM PARA LAS MONEDAS DE LA CALCULADORA ---
enum MonedaCalculadora { dolar, euro, bs }

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final DolarApiService _apiService = DolarApiService();
  double _tasaActualDolar = 0.0;
  double _tasaActualEuro = 0.0;
  double _tasaPersonalizada = 0.0;
  String _fechaActualizacion = '';
  bool _isLoading = true;

  ModoVista _modoActual = ModoVista.dolar;

  // --- NUEVA VARIABLE DE ESTADO PARA LA CALCULADORA ---
  MonedaCalculadora _monedaMath = MonedaCalculadora.dolar;

  final TextEditingController _foreignController =
      TextEditingController(text: "1,00");
  final TextEditingController _bsController = TextEditingController();
  final TextEditingController _customRateController =
      TextEditingController(text: "1,00");

  final TextEditingController _mathController = TextEditingController();
  final ScrollController _mathScrollController = ScrollController();

  // --- VARIABLES DE RESULTADO EXPANDIDAS ---
  double _mathResultBs = 0.0;
  double _mathResultDolar = 0.0;
  double _mathResultEuro = 0.0;
  bool _mathError = false;

  final NumberFormat _formatoInyeccion = NumberFormat("#,##0.00", "es_VE");
  final NumberFormat _formatoTasa =
      NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _cargarTodasLasTasas();
  }

  Future<void> _cargarTodasLasTasas() async {
    final dataDolar = await _apiService.getTasas(true);
    final dataEuro = await _apiService.getTasas(false);

    if (dataDolar != null && dataEuro != null && mounted) {
      setState(() {
        _tasaActualDolar = (dataDolar['promedio'] ?? 0).toDouble();
        _tasaActualEuro = (dataEuro['promedio'] ?? 0).toDouble();
        _tasaPersonalizada = _tasaActualDolar;
        _customRateController.text =
            _formatoInyeccion.format(_tasaPersonalizada);

        DateTime fecha = DateTime.parse(dataDolar['fechaActualizacion']);
        _fechaActualizacion = DateFormat('dd/MM/yyyy').format(fecha);
        _isLoading = false;

        _convertirDivisaABs(_foreignController.text);
      });
    }
  }

  double _getTasaActiva() {
    if (_modoActual == ModoVista.dolar) return _tasaActualDolar;
    if (_modoActual == ModoVista.euro) return _tasaActualEuro;
    if (_modoActual == ModoVista.personalizada) return _tasaPersonalizada;
    return _tasaActualDolar;
  }

  void _convertirDivisaABs(String valor) {
    double tasa = _getTasaActiva();
    if (tasa == 0 || valor.isEmpty) {
      _bsController.text = '';
      return;
    }
    String valorLimpio = valor.replaceAll('.', '').replaceAll(',', '.');
    double divisa = double.tryParse(valorLimpio) ?? 0.0;
    _bsController.text = _formatoInyeccion.format(divisa * tasa);
  }

  void _convertirBsADivisa(String valor) {
    double tasa = _getTasaActiva();
    if (tasa == 0 || valor.isEmpty) {
      _foreignController.text = '';
      return;
    }
    String valorLimpio = valor.replaceAll('.', '').replaceAll(',', '.');
    double bs = double.tryParse(valorLimpio) ?? 0.0;
    _foreignController.text = _formatoInyeccion.format(bs / tasa);
  }

  void _evaluarMatematica(String expresion) {
    if (expresion.isEmpty) {
      setState(() {
        _mathResultBs = 0.0;
        _mathResultDolar = 0.0;
        _mathResultEuro = 0.0;
        _mathError = false;
      });
      return;
    }
    try {
      String textoLimpio = expresion
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .replaceAll('x', '*');
      Parser p = Parser();
      Expression exp = p.parse(textoLimpio);
      double resultado = exp.evaluate(EvaluationType.REAL, ContextModel());

      if (resultado.isInfinite || resultado.isNaN) {
        setState(() => _mathError = true);
        return;
      }

      // --- LÓGICA DE CÁLCULO TRIPLE ---
      setState(() {
        _mathError = false;
        if (_monedaMath == MonedaCalculadora.dolar) {
          _mathResultDolar = resultado;
          _mathResultBs = resultado * _tasaActualDolar;
          _mathResultEuro =
              _tasaActualEuro > 0 ? _mathResultBs / _tasaActualEuro : 0.0;
        } else if (_monedaMath == MonedaCalculadora.euro) {
          _mathResultEuro = resultado;
          _mathResultBs = resultado * _tasaActualEuro;
          _mathResultDolar =
              _tasaActualDolar > 0 ? _mathResultBs / _tasaActualDolar : 0.0;
        } else {
          // Es Bolívares
          _mathResultBs = resultado;
          _mathResultDolar =
              _tasaActualDolar > 0 ? resultado / _tasaActualDolar : 0.0;
          _mathResultEuro =
              _tasaActualEuro > 0 ? resultado / _tasaActualEuro : 0.0;
        }
      });
    } catch (e) {
      // Silencioso
    }
  }

  void _onCalcButtonPressed(String valor) {
    final text = _mathController.text;
    final selection = _mathController.selection;
    int cursorPosition = selection.baseOffset;
    if (cursorPosition < 0) cursorPosition = text.length;

    if (valor == 'C') {
      _mathController.clear();
    } else if (valor == '⌫') {
      if (cursorPosition > 0) {
        final newText = text.substring(0, cursorPosition - 1) +
            text.substring(cursorPosition);
        _mathController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursorPosition - 1));
      }
    } else {
      final newText = text.substring(0, cursorPosition) +
          valor +
          text.substring(cursorPosition);
      _mathController.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: cursorPosition + valor.length));
    }
    _evaluarMatematica(_mathController.text);
  }

  void _copiarAlPortapapeles(String texto) {
    if (texto.isEmpty || texto == "0,00" || _mathError) return;
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('¡Copiado!',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1)));
  }

  Widget _construirMenuPegar(
      BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          onPressed: () async {
            editableTextState.pasteText(SelectionChangedCause.toolbar);
            editableTextState.hideToolbar();
            await Future.delayed(const Duration(milliseconds: 50));
            _evaluarMatematica(_mathController.text);
          },
          label: 'Pegar',
        ),
      ],
    );
  }

  void _restablecerValores() {
    _foreignController.text = "1,00";
    _mathController.clear();
    _evaluarMatematica("");
    _cargarTodasLasTasas();
  }

  @override
  Widget build(BuildContext context) {
    double tasaAMostrar = _getTasaActiva();
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('💱 Conversor BCV',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _restablecerValores)
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _modoActual.index,
        onTap: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');

          setState(() {
            _modoActual = ModoVista.values[index];
            _foreignController.text = "1,00";
            _mathController.clear();
            _monedaMath = MonedaCalculadora
                .dolar; // Reseteamos la calculadora al dólar por defecto

            if (_modoActual != ModoVista.calculadora) {
              _convertirDivisaABs("1,00");
            } else {
              _evaluarMatematica("");
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.attach_money), label: 'Dólar'),
          BottomNavigationBarItem(icon: Icon(Icons.euro), label: 'Euro'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Pers'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Calc'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                      decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16))),
                      child: Center(
                        child: Text(
                          _modoActual == ModoVista.dolar
                              ? 'Dólar BCV'
                              : _modoActual == ModoVista.euro
                                  ? 'Euro BCV'
                                  : _modoActual == ModoVista.personalizada
                                      ? 'Tasa Personalizada'
                                      : 'Calculadora Múltiple',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(screenHeight * 0.02),
                      child: _modoActual == ModoVista.calculadora
                          ? _buildCalculadoraUnificada(screenHeight)
                          : _buildConversorNormal(screenHeight, tasaAMostrar),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: screenHeight * 0.015),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_fechaActualizacion,
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _modoActual == ModoVista.calculadora
                                  ? 'Base Dólar: ${_formatoTasa.format(_tasaActualDolar)}'
                                  : _modoActual == ModoVista.personalizada
                                      ? 'Tasa Base: ${_formatoTasa.format(_tasaPersonalizada)}'
                                      : '1 ${_modoActual == ModoVista.dolar ? "USD" : "EUR"} = ${_formatoTasa.format(tasaAMostrar)}',
                              style: TextStyle(
                                  color: _modoActual == ModoVista.personalizada
                                      ? Colors.orangeAccent
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConversorNormal(double screenHeight, double tasaAMostrar) {
    return Column(
      children: [
        if (_modoActual == ModoVista.personalizada) ...[
          TextField(
            controller: _customRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FormatoMiles()],
            onChanged: (valor) {
              String valorLimpio =
                  valor.replaceAll('.', '').replaceAll(',', '.');
              setState(() =>
                  _tasaPersonalizada = double.tryParse(valorLimpio) ?? 0.0);
              _convertirDivisaABs(_foreignController.text);
            },
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent),
            decoration: const InputDecoration(
                prefixIcon: Text('Tasa: ',
                    style: TextStyle(color: Colors.orangeAccent))),
          ),
        ],
        TextField(
          controller: _foreignController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FormatoMiles()],
          onChanged: _convertirDivisaABs,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
              prefixIcon: Text(_modoActual == ModoVista.euro ? '€ ' : '\$ ')),
        ),
        SizedBox(height: screenHeight * 0.03),
        TextField(
          controller: _bsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FormatoMiles()],
          onChanged: _convertirBsADivisa,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(prefixIcon: Text('Bs ')),
        ),
      ],
    );
  }

  Widget _buildCalculadoraUnificada(double screenHeight) {
    return Column(
      children: [
        TextField(
          controller: _mathController,
          scrollController: _mathScrollController,
          readOnly: true,
          showCursor: true,
          keyboardType: TextInputType.none,
          contextMenuBuilder: _construirMenuPegar,
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: 1),
          decoration: InputDecoration(
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),

            // --- NUEVO: MENU DESPLEGABLE EN EL ICONO DE LA CALCULADORA ---
            prefixIcon: PopupMenuButton<MonedaCalculadora>(
              initialValue: _monedaMath,
              color: Colors.grey.shade900,
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (MonedaCalculadora monedaSeleccionada) {
                setState(() {
                  _monedaMath = monedaSeleccionada;
                  _evaluarMatematica(_mathController.text);
                });
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<MonedaCalculadora>>[
                const PopupMenuItem<MonedaCalculadora>(
                  value: MonedaCalculadora.dolar,
                  child: Text('\$ Dólar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem<MonedaCalculadora>(
                  value: MonedaCalculadora.euro,
                  child: Text('€ Euro',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuItem<MonedaCalculadora>(
                  value: MonedaCalculadora.bs,
                  child: Text('Bs Bolívar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 12.0, right: 8.0, top: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _monedaMath == MonedaCalculadora.dolar
                          ? '\$'
                          : _monedaMath == MonedaCalculadora.euro
                              ? '€'
                              : 'Bs',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down,
                        size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),

            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),

        // --- NUEVO: PANEL DE RESULTADOS 3 EN 1 ---
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Total Bs:",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                        _mathError
                            ? "Error"
                            : _formatoTasa.format(_mathResultBs),
                        style: TextStyle(
                            fontSize: _mathError ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color:
                                _mathError ? Colors.redAccent : Colors.white)),
                  ),
                ),
              ]),
              const Divider(color: Colors.white10, height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("En Dólares:",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                Flexible(
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                            _mathError
                                ? "Error"
                                : "\$ ${_formatoInyeccion.format(_mathResultDolar)}",
                            style: TextStyle(
                                fontSize: _mathError ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: _mathError
                                    ? Colors.redAccent
                                    : Colors.greenAccent)),
                      ),
                    ),
                    if (!_mathError)
                      IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                          onPressed: () => _copiarAlPortapapeles(
                              _formatoInyeccion.format(_mathResultDolar)))
                  ]),
                )
              ]),
              const Divider(color: Colors.white10, height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("En Euros:",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                Flexible(
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                            _mathError
                                ? "Error"
                                : "€ ${_formatoInyeccion.format(_mathResultEuro)}",
                            style: TextStyle(
                                fontSize: _mathError ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: _mathError
                                    ? Colors.redAccent
                                    : Colors.cyanAccent)),
                      ),
                    ),
                    if (!_mathError)
                      IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                          onPressed: () => _copiarAlPortapapeles(
                              _formatoInyeccion.format(_mathResultEuro)))
                  ]),
                )
              ])
            ])),
        SizedBox(height: screenHeight * 0.02),
        Column(
          children: [
            Row(children: [
              _btnCalc('C', screenHeight, color: Colors.red.shade400),
              _btnCalc('⌫', screenHeight, color: Colors.grey.shade700),
              _btnCalc('(', screenHeight, color: Colors.grey.shade700),
              _btnCalc(')', screenHeight, color: Colors.grey.shade700),
            ]),
            Row(children: [
              _btnCalc('7', screenHeight),
              _btnCalc('8', screenHeight),
              _btnCalc('9', screenHeight),
              _btnCalc('/', screenHeight, color: Colors.green.shade800),
            ]),
            Row(children: [
              _btnCalc('4', screenHeight),
              _btnCalc('5', screenHeight),
              _btnCalc('6', screenHeight),
              _btnCalc('x', screenHeight, color: Colors.green.shade800),
            ]),
            Row(children: [
              _btnCalc('1', screenHeight),
              _btnCalc('2', screenHeight),
              _btnCalc('3', screenHeight),
              _btnCalc('-', screenHeight, color: Colors.green.shade800),
            ]),
            Row(children: [
              _btnCalc('0', screenHeight),
              _btnCalc(',', screenHeight),
              _btnCalc('+', screenHeight),
            ]),
          ],
        )
      ],
    );
  }

  Widget _btnCalc(String texto, double screenHeight, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () => _onCalcButtonPressed(texto),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.022),
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(texto,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foreignController.dispose();
    _bsController.dispose();
    _customRateController.dispose();
    _mathController.dispose();
    _mathScrollController.dispose();
    super.dispose();
  }
}
