import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stream_model.dart';
import '../models/user_model.dart';

/// Communicates with the Cloudflare Worker relay and reads Soroban stream state.
///
/// All write operations (create_stream, withdraw, cancel) go via the Worker
/// which builds the Soroban XDR, signs it, wraps in fee_bump, and submits.
/// All read operations (get_stream, unlocked_balance) go directly to Horizon/RPC.
class StellarService {
  /// TODO: replace with your deployed Worker URL from `wrangler deploy`
  static const String _workerUrl =
      'https://inflow-relay.your-domain.workers.dev';

  String? _publicKey;
  String _network = 'testnet';

  // ─── Getters ──────────────────────────────────────────────────────────────

  String? get publicKey => _publicKey;
  String get network => _network;
  bool get isConnected => _publicKey != null;

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /// Sends a 6-digit OTP to [email] via Resend API (through the Worker).
  Future<void> sendOtp(String email) async {
    final res = await http.post(
      Uri.parse('$_workerUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to send OTP: ${res.body}');
    }
  }

  /// Verifies [otp] for [email], derives the Ed25519 keypair on the Worker,
  /// and returns the resulting [UserModel].
  Future<UserModel> verifyOtpAndConnect(
      String email, String otp, String network) async {
    final res = await http.post(
      Uri.parse('$_workerUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'network': network}),
    );
    if (res.statusCode != 200) {
      throw Exception('Invalid OTP: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _publicKey = data['publicKey'] as String;
    _network = (data['network'] as String?) ?? network;
    return UserModel.fromJson(data, email);
  }

  /// Restores a previously authenticated session from a saved [UserModel].
  void restoreSession(UserModel user) {
    _publicKey = user.publicKey;
    _network = user.network;
  }

  /// Clears the in-memory session. Call [StorageService.clearUser] separately.
  void logout() {
    _publicKey = null;
    _network = 'testnet';
  }

  // ─── Stream Reads ─────────────────────────────────────────────────────────

  /// Fetches stream metadata stored by the Worker (sender email, recipient
  /// email, network) — used when opening a payment claim link.
  Future<Map<String, dynamic>> getStreamInfo(String streamId) async {
    final res = await http.get(
      Uri.parse('$_workerUrl/stream-info?id=$streamId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch stream info');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Contract Write Relay ─────────────────────────────────────────────────

  /// Generic relay to invoke a Soroban contract method through the Worker.
  ///
  /// The Worker constructs, signs, fee-bumps, and submits the transaction.
  /// Returns the response body as a JSON map.
  Future<Map<String, dynamic>> invokeContract(
      String method, Map<String, dynamic> args) async {
    if (_publicKey == null) throw Exception('Not authenticated');
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

  /// Creates a new salary stream.
  Future<int> createStream({
    required String tokenAddress,
    required double depositUsdc,
    required DateTime startTime,
    required DateTime stopTime,
    String? recipientAddress,
    String? recipientEmail, // If set, Worker creates claim_hash
  }) async {
    final result = await invokeContract('create_stream', {
      'token': tokenAddress,
      'deposit': (depositUsdc * 10_000_000).toInt(), // 7 decimal stroops
      'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
      'stop_time': stopTime.millisecondsSinceEpoch ~/ 1000,
      if (recipientAddress != null) 'recipient': recipientAddress,
      if (recipientEmail != null) 'recipient_email': recipientEmail,
    });
    return (result['stream_id'] as int?) ?? 0;
  }

  /// Withdraws [amountUsdc] from a stream. Recipient auth is handled by the Worker.
  Future<String> withdraw(int streamId, double amountUsdc) async {
    final result = await invokeContract('withdraw', {
      'stream_id': streamId,
      'amount': (amountUsdc * 10_000_000).toInt(),
    });
    return (result['txHash'] as String?) ?? '';
  }

  /// Cancels a stream. Returns the pro-rata split amounts.
  Future<Map<String, dynamic>> cancelStream(int streamId) async {
    return invokeContract('cancel_stream', {'stream_id': streamId});
  }

  /// Requests fee_bump sponsorship for a new account (testnet: friendbot,
  /// mainnet: treasury XLM transfer).
  Future<void> triggerSponsorship(String address) async {
    await http.post(
      Uri.parse('$_workerUrl/trigger-sponsorship'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'network': _network}),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Parses raw stream JSON returned from the contract via the Worker.
  StreamModel parseStream(Map<String, dynamic> json, int streamId) {
    return StreamModel.fromJson({...json, 'stream_id': streamId});
  }
}
