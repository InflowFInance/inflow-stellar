import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inFlow Stream Rate Math Unit Tests', () {
    test('Calculates per-second rate correctly for 30-day USDC salary stream', () {
      const double totalDeposit = 3000.0; // $3,000 USDC
      const int durationDays = 30;
      const int durationSeconds = durationDays * 86400; // 2,592,000 seconds

      final double ratePerSecond = totalDeposit / durationSeconds;

      // $3000 / 2592000s = 0.0011574074... $/sec
      expect(ratePerSecond, closeTo(0.0011574, 0.0000001));
      expect(ratePerSecond * 86400, closeTo(100.0, 0.01)); // $100 / day
    });

    test('Clamps unlocked amount between 0 and total deposit', () {
      const double deposit = 500.0;
      
      // Before start time
      double timePassed = -50.0;
      double progress = (timePassed / 86400).clamp(0.0, 1.0);
      double unlocked = (progress * deposit).clamp(0.0, deposit);
      expect(unlocked, equals(0.0));

      // 50% through duration
      timePassed = 43200.0;
      progress = (timePassed / 86400).clamp(0.0, 1.0);
      unlocked = (progress * deposit).clamp(0.0, deposit);
      expect(unlocked, equals(250.0));

      // After stop time
      timePassed = 100000.0;
      progress = (timePassed / 86400).clamp(0.0, 1.0);
      unlocked = (progress * deposit).clamp(0.0, deposit);
      expect(unlocked, equals(500.0));
    });

    test('Calculates remaining withdrawable balance accurately', () {
      const double deposit = 1000.0;
      const double unlocked = 400.0;
      const double alreadyWithdrawn = 150.0;

      final double availableToWithdraw = (unlocked - alreadyWithdrawn).clamp(0.0, deposit);
      expect(availableToWithdraw, equals(250.0));
    });
  });
}
