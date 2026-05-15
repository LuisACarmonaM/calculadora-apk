import 'dart:convert';
import 'package:http/http.dart' as http;

class DolarApiService {
  final String _baseUrl = 'https://ve.dolarapi.com/v1/dolares/oficial';

  Future<Map<String, dynamic>?> getTasas() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('DolarAPI respondió con status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error DolarAPI tasas: $e');
      return null;
    }
  }
}
