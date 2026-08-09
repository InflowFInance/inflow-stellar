import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8787');

  Future<Map<String, dynamic>> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return jsonDecode(response.body);
  }
}
