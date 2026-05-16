import 'dart:convert';
import 'package:http/http.dart' as http;

class DolarApiService {
  final String _urlDolar = 'https://ve.dolarapi.com/v1/dolares/oficial';
  final String _urlEuro = 'https://ve.dolarapi.com/v1/euros/oficial';

  // Ahora recibe un booleano para cambiar dinámicamente de URL
  Future<Map<String, dynamic>?> getTasas(bool esDolar) async {
    final String urlFinal = esDolar ? _urlDolar : _urlEuro;

    try {
      final response = await http.get(Uri.parse(urlFinal)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('API respondió con status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error API tasas: $e');
      return null;
    }
  }
}
