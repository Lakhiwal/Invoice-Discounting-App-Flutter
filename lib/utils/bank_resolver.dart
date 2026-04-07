import 'package:flutter/material.dart';

class BankInfo {
  final String name;
  final Color brandColor;
  final String? logoUrl;

  const BankInfo({
    required this.name,
    required this.brandColor,
    this.logoUrl,
  });
}

class BankResolver {
  static const Map<String, BankInfo> _topBanks = {
    'HDFC': BankInfo(
      name: 'HDFC Bank',
      brandColor: Color(0xFF1E3170),
    ),
    'ICIC': BankInfo(
      name: 'ICICI Bank',
      brandColor: Color(0xFFF37D21),
    ),
    'SBIN': BankInfo(
      name: 'State Bank of India',
      brandColor: Color(0xFF00A9E0),
    ),
    'AXIS': BankInfo(
      name: 'Axis Bank',
      brandColor: Color(0xFF971237),
    ),
    'UTIB': BankInfo(
      name: 'Axis Bank',
      brandColor: Color(0xFF971237),
    ),
    'KKBK': BankInfo(
      name: 'Kotak Mahindra Bank',
      brandColor: Color(0xFFEE2E24),
    ),
    'YESB': BankInfo(
      name: 'Yes Bank',
      brandColor: Color(0xFF0055A5),
    ),
    'BARB': BankInfo(
      name: 'Bank of Baroda',
      brandColor: Color(0xFFF15A22),
    ),
    'PUNB': BankInfo(
      name: 'Punjab National Bank',
      brandColor: Color(0xFFA2192E),
    ),
    'INDB': BankInfo(
      name: 'IndusInd Bank',
      brandColor: Color(0xFF91191C),
    ),
    'UBIN': BankInfo(
      name: 'Union Bank of India',
      brandColor: Color(0xFFE21E26),
    ),
    'IDFB': BankInfo(
      name: 'IDFC First Bank',
      brandColor: Color(0xFF9E1B1E),
    ),
    'AUBL': BankInfo(
      name: 'AU Small Finance Bank',
      brandColor: Color(0xFF2E3192),
    ),
    'CNRB': BankInfo(
      name: 'Canara Bank',
      brandColor: Color(0xFF0054A6),
    ),
    'FDRL': BankInfo(
      name: 'Federal Bank',
      brandColor: Color(0xFF0054A6),
    ),
    'RATN': BankInfo(
      name: 'RBL Bank',
      brandColor: Color(0xFF0054A6),
    ),
    'BDBL': BankInfo(
      name: 'Bandhan Bank',
      brandColor: Color(0xFF0054A6),
    ),
  };

  /// Main entry point to resolve bank info from IFSC
  static BankInfo resolve(String ifsc) {
    if (ifsc.length < 4) return _default;
    
    final prefix = ifsc.substring(0, 4).toUpperCase();
    final lowerPrefix = prefix.toLowerCase();
    
    // Pattern for the reliable indian-banks repository (using symbol.svg for vector crispness)
    final logoUrl = 'https://raw.githubusercontent.com/praveenpuglia/indian-banks/main/assets/logos/$lowerPrefix/symbol.svg';
    
    final known = _topBanks[prefix];
    if (known != null) {
      return BankInfo(
        name: known.name,
        brandColor: known.brandColor,
        logoUrl: logoUrl,
      );
    }

    // Dynamic resolution for unknown banks if prefix is valid
    return BankInfo(
      name: 'Bank $prefix',
      brandColor: const Color(0xFF1A73E8),
      logoUrl: logoUrl,
    );
  }

  static BankInfo get _default => const BankInfo(
        name: 'Bank Account',
        brandColor: Color(0xFF1A73E8),
      );
}
