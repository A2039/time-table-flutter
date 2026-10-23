import 'package:google_fonts/google_fonts.dart';

/// Typography configuration using Plus Jakarta Sans for crisp, modern legibility
class AppTypography {
  AppTypography._();

  /// Primary font family name
  static String? get fontFamily {
    try {
      return GoogleFonts.plusJakartaSans().fontFamily;
    } catch (_) {
      return null;
    }
  }
}
