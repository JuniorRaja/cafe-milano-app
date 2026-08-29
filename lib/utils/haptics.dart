import 'package:flutter/services.dart';

/// Every haptic in the app, in one place.
///
/// Android maps Flutter's four impact levels onto `HapticFeedbackConstants`
/// unevenly: `lightImpact` becomes `CLOCK_TICK` and `heavyImpact` becomes
/// `CONTEXT_CLICK`, and a great many phones map neither to anything at all.
/// That is why the quantity wheel and the steppers felt dead on the device
/// while the code looked correct. `KEYBOARD_TAP` and `LONG_PRESS` are the two
/// constants OEMs reliably implement.
///
/// Feel is a physical property. It needs one knob to tune against a real
/// phone, not the same constant copied into five call sites.
///
/// Both still obey the system touch-vibration setting — if that is off,
/// nothing here fires, and no app-side change can make it.
class AppHaptics {
  const AppHaptics._();

  /// A stepper press, a wheel digit, a row tap. `KEYBOARD_TAP`.
  static Future<void> tap() => HapticFeedback.mediumImpact();

  /// The order is confirmed. Deliberately longer than [tap] so it is not
  /// mistaken for one. `LONG_PRESS`.
  static Future<void> success() => HapticFeedback.vibrate();
}
