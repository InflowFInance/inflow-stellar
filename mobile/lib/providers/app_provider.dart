import 'package:flutter/foundation.dart';
import '../models/stream_model.dart';
import '../models/user_model.dart';
import '../services/stellar_service.dart';
import '../services/storage_service.dart';

enum AuthState { unauthenticated, sendingOtp, otpSent, verifying, authenticated }

/// Central application state using ChangeNotifier.
///
/// Screens listen to this provider via context.watch / context.read.
/// It owns the auth flow, streams list, and all loading/error state.
class AppProvider extends ChangeNotifier {
  final StellarService stellarService;
  final StorageService storageService;

  AppProvider({required this.stellarService, required this.storageService});

  // ─── Auth State ───────────────────────────────────────────────────────────

  AuthState _authState = AuthState.unauthenticated;
  AuthState get authState => _authState;

  UserModel? _user;
  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;

  String? _authError;
  String? get authError => _authError;

  // ─── Stream State ─────────────────────────────────────────────────────────

  List<StreamModel> _streams = [];
  List<StreamModel> get streams => List.unmodifiable(_streams);

  bool _streamsLoading = false;
  bool get streamsLoading => _streamsLoading;

  String? _streamsError;
  String? get streamsError => _streamsError;

  // ─── Session Restore ──────────────────────────────────────────────────────

  /// Called on app start. Restores session from secure storage if available.
  Future<void> initialize() async {
    final saved = await storageService.loadUser();
    if (saved != null) {
      stellarService.restoreSession(saved);
      _user = saved;
      _authState = AuthState.authenticated;
      notifyListeners();
    }
  }

  // ─── Auth Actions ─────────────────────────────────────────────────────────

  Future<void> sendOtp(String email) async {
    _authState = AuthState.sendingOtp;
    _authError = null;
    notifyListeners();
    try {
      await stellarService.sendOtp(email);
      _authState = AuthState.otpSent;
    } catch (e) {
      _authError = e.toString();
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> verifyOtp(String email, String otp) async {
    _authState = AuthState.verifying;
    _authError = null;
    notifyListeners();
    try {
      final user = await stellarService.verifyOtpAndConnect(
          email, otp, stellarService.network);
      _user = user;
      await storageService.saveUser(user);
      _authState = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString();
      _authState = AuthState.otpSent;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    stellarService.logout();
    _user = null;
    _streams = [];
    _authState = AuthState.unauthenticated;
    await storageService.clearUser();
    notifyListeners();
  }

  // ─── Stream Actions ───────────────────────────────────────────────────────

  /// Fetches a single stream by ID and updates the local list.
  Future<void> loadStream(int streamId) async {
    _streamsLoading = true;
    _streamsError = null;
    notifyListeners();
    try {
      final info = await stellarService.getStreamInfo(streamId.toString());
      if (info['found'] == true) {
        final stream = stellarService.parseStream(info, streamId);
        final idx = _streams.indexWhere((s) => s.streamId == streamId);
        if (idx >= 0) {
          _streams[idx] = stream;
        } else {
          _streams = [..._streams, stream];
        }
      }
    } catch (e) {
      _streamsError = e.toString();
    }
    _streamsLoading = false;
    notifyListeners();
  }

  /// Withdraws all available USDC from [stream].
  Future<String?> withdraw(StreamModel stream) async {
    final available = stream.availableToWithdraw(DateTime.now());
    if (available <= 0) return null;
    try {
      final txHash = await stellarService.withdraw(stream.streamId, available);
      // Optimistically update local state
      final updated = stream.copyWith(
        withdrawnAmount: stream.withdrawnAmount + available,
        remainingBalance: stream.remainingBalance - available,
      );
      final idx = _streams.indexWhere((s) => s.streamId == stream.streamId);
      if (idx >= 0) {
        final list = [..._streams];
        list[idx] = updated;
        _streams = list;
        notifyListeners();
      }
      return txHash;
    } catch (e) {
      _streamsError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Cancels [stream] and splits the remaining balance pro-rata.
  Future<void> cancelStream(StreamModel stream) async {
    try {
      await stellarService.cancelStream(stream.streamId);
      _streams = _streams.where((s) => s.streamId != stream.streamId).toList();
      notifyListeners();
    } catch (e) {
      _streamsError = e.toString();
      notifyListeners();
    }
  }
}
