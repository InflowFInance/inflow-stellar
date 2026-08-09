import 'dart:async';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class InflowWebPlugin {
  static void registerWith(Registrar registrar) {
    // StellarBridge.js interop will be initialized here
    // This provides a bridge between Flutter and the Stellar JS SDK
  }

  static Future<String> getPublicKey() async {
    // TODO: Call StellarBridge.js to get deterministic public key
    return Future.value('');
  }

  static Future<String> signTransaction(String xdr) async {
    // TODO: Call StellarBridge.js to sign transaction
    return Future.value(xdr);
  }
}
