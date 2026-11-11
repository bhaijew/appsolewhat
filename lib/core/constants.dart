import 'package:flutter/material.dart';

class AppConstants {
  // Supabase Configuration (Admin Client with full Service Role access for Branch Command Center)
  static const String supabaseUrl = 'https://uadrrjrlhfttithjmdye.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZHJyanJsaGZ0dGl0aGptZHllIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MDYwNTg2OCwiZXhwIjoyMTA2MTgxODY4fQ.NuC74GhFlUEiaRR2BXPooYj7iahzrXXKCxMQYDUnfIg';

  // Default Admin Password (matches pizza-main ADMIN_PASSWORD)
  static const String adminPassword = 'hal123';

  // Currency
  static const String currency = 'Rs. ';

  // Brand Images
  static const String brandLogo = 'assets/images/solewhat-logo.png';
  static const String brandIcon = 'assets/images/solewhat-icon.png';

  // 5px UI Square Radius
  static const double r5 = 5.0;
  static final BorderRadius radius5 = BorderRadius.circular(5.0);

  // Modern Clean White Theme Colors
  static const Color primary = Color(0xFFDC2626); // Crimson Red
  static const Color primaryDark = Color(0xFF991B1B);
  static const Color secondary = Color(0xFFEA580C); // Ember Orange
  static const Color accent = Color(0xFFF59E0B); // Amber
  
  static const Color bgLight = Color(0xFFF8FAFC); // Clean Off-White
  static const Color cardLight = Color(0xFFFFFFFF); // Pure White Card
  static const Color surfaceLight = Color(0xFFF1F5F9); // Light Gray Surface
  static const Color borderLight = Color(0xFFE2E8F0); // Subtle Slate Border
  
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textBody = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Status Colors
  static const Color statusPending = Color(0xFFD97706); // Warm Amber
  static const Color statusPreparing = Color(0xFF2563EB); // Royal Blue
  static const Color statusDelivery = Color(0xFF7C3AED); // Purple
  static const Color statusDelivered = Color(0xFF059669); // Emerald Green
  static const Color statusCancelled = Color(0xFFDC2626); // Crimson
}
