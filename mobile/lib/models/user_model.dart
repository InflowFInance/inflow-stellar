/// Represents an authenticated user session (email + Stellar keypair).
class UserModel {
  final String email;
  final String publicKey;
  final String network;

  const UserModel({
    required this.email,
    required this.publicKey,
    required this.network,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String email) {
    return UserModel(
      email: email,
      publicKey: (json['publicKey'] as String?) ?? '',
      network: (json['network'] as String?) ?? 'testnet',
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'publicKey': publicKey,
        'network': network,
      };

  /// Abbreviates the public key for display, e.g. "GABCD…XYZ"
  String get shortPublicKey {
    if (publicKey.length < 10) return publicKey;
    return '${publicKey.substring(0, 6)}…${publicKey.substring(publicKey.length - 4)}';
  }
}
