import 'package:flutter/material.dart';

/// Design tokens adapted directly from service-mobile UI reference
class UiTone {
  static const Color shellBackground = Color(0xFFF8FAFC);
  static const Color shellAccent = Color(0xFFE6F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceBorder = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color softText = Color(0xFF475569);
  static const Color primary = Color(0xFF0D7C66);
  static const Color primaryDark = Color(0xFF0A5C4C);
  static const Color primarySoft = Color(0xFFE6F5F0);
  static const Color secondary = Color(0xFF10B766);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color border = Color(0xFFDCE5E0);
  static const Color divider = Color(0xFFE0E9E4);
}

class UiSpace {
  static const EdgeInsets screen = EdgeInsets.fromLTRB(16, 14, 16, 24);
  static const EdgeInsets section = EdgeInsets.fromLTRB(16, 14, 16, 12);

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard horizontal screen gutter used across customer screens.
  static const double gutter = 16;
  static const EdgeInsets hGutter = EdgeInsets.symmetric(horizontal: 16);

  /// Default card interior padding.
  static const EdgeInsets card = EdgeInsets.all(14);
}

class UiRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double pill = 999;
}

class UiShadow {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> glowPrimary = <BoxShadow>[
    BoxShadow(color: Color(0x220D7C66), blurRadius: 16, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A0D7C66), blurRadius: 32, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> floatingNav = <BoxShadow>[
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x060D7C66), blurRadius: 40, offset: Offset(0, 16)),
  ];

  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(color: Color(0x0C0F172A), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x100F172A), blurRadius: 32, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 48, offset: Offset(0, 16)),
  ];
}

class UiGradient {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0D7C66), Color(0xFF14A38B)],
  );
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF16A267), Color(0xFF0E784D)],
  );
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
  );
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
  );
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFEF3C7), Color(0xFFFDE68A)],
  );
}
