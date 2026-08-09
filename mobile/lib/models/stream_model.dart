/// Represents a salary stream returned from the Soroban contract.
class StreamModel {
  final int streamId;
  final String sender;
  final String? recipient;
  final String token;
  final double deposit;
  final double ratePerSecond;
  final int startTime;
  final int stopTime;
  final double withdrawnAmount;
  final double remainingBalance;
  final bool isActive;

  const StreamModel({
    required this.streamId,
    required this.sender,
    this.recipient,
    required this.token,
    required this.deposit,
    required this.ratePerSecond,
    required this.startTime,
    required this.stopTime,
    required this.withdrawnAmount,
    required this.remainingBalance,
    required this.isActive,
  });

  factory StreamModel.fromJson(Map<String, dynamic> json) {
    final deposit = _toDouble(json['deposit']);
    final start = (json['start_time'] as int?) ?? 0;
    final stop = (json['stop_time'] as int?) ?? 0;
    final duration = stop - start;
    final rate = duration > 0 ? deposit / duration : 0.0;

    return StreamModel(
      streamId: (json['stream_id'] as int?) ?? 0,
      sender: (json['sender'] as String?) ?? '',
      recipient: json['recipient'] as String?,
      token: (json['token'] as String?) ?? '',
      deposit: deposit,
      ratePerSecond: rate,
      startTime: start,
      stopTime: stop,
      withdrawnAmount: _toDouble(json['withdrawn_amount']),
      remainingBalance: _toDouble(json['remaining_balance']),
      isActive: (json['remaining_balance'] as int? ?? 0) > 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v / 10_000_000.0; // Stellar 7-decimal stroops
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// How many USDC have accrued since stream start, as of [now].
  double unlockedBalance(DateTime now) {
    final nowTs = now.millisecondsSinceEpoch ~/ 1000;
    if (nowTs <= startTime) return 0.0;
    final elapsed = (nowTs - startTime).clamp(0, stopTime - startTime);
    return ratePerSecond * elapsed;
  }

  /// How much is claimable right now (unlocked minus already withdrawn).
  double availableToWithdraw(DateTime now) {
    return (unlockedBalance(now) - withdrawnAmount).clamp(0.0, deposit);
  }

  /// Progress from 0.0 to 1.0 based on elapsed time.
  double progressFraction(DateTime now) {
    if (stopTime <= startTime) return 0.0;
    final nowTs = now.millisecondsSinceEpoch ~/ 1000;
    return ((nowTs - startTime) / (stopTime - startTime)).clamp(0.0, 1.0);
  }

  DateTime get startDate =>
      DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
  DateTime get stopDate =>
      DateTime.fromMillisecondsSinceEpoch(stopTime * 1000);

  StreamModel copyWith({double? withdrawnAmount, double? remainingBalance}) {
    return StreamModel(
      streamId: streamId,
      sender: sender,
      recipient: recipient,
      token: token,
      deposit: deposit,
      ratePerSecond: ratePerSecond,
      startTime: startTime,
      stopTime: stopTime,
      withdrawnAmount: withdrawnAmount ?? this.withdrawnAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      isActive: (remainingBalance ?? this.remainingBalance) > 0,
    );
  }
}
