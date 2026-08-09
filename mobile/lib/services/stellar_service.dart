import 'dart:convert';
import 'package:http/http.dart' as http;

class StellarService {
  static const String _workerUrl = 'https://inflow-relay.your-domain.workers.dev';

  String? _publicKey;
  String _network = 'testnet';

  String? get publicKey => _publicKey;
  String get network => _network;
  bool get isConnected => _publicKey != null;

  Future<void> sendOtp(String email) async {
    final res = await http.post(
      Uri.parse('$_workerUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to send OTP code');
    }
  }

  Future<String> verifyOtpAndConnect(String email, String otp, String network) async {
    final res = await http.post(
      Uri.parse('$_workerUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'network': network}),
    );
    if (res.statusCode != 200) {
      throw Exception('Invalid OTP verification code');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _publicKey = data['publicKey'] as String;
    _network = (data['network'] as String?) ?? network;
    return _publicKey!;
  }

  Future<Map<String, dynamic>> invokeContract(String method, Map<String, dynamic> args) async {
    final res = await http.post(
      Uri.parse('$_workerUrl/invoke'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': method,
        'signerPublicKey': _publicKey,
        'args': args,
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStreamInfo(String streamId) async {
    final res = await http.get(
      Uri.parse('$_workerUrl/stream-info?id=$streamId'),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    _publicKey = null;
  }
}
