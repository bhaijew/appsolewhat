import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import 'main_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pwdCtrl = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final entered = _pwdCtrl.text.trim();
    if (entered.isEmpty) {
      setState(() => _errorMsg = 'Please enter your branch password or PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Auto-verify which branch/outlet this password or PIN belongs to
    final res = await SupabaseService.instance.loginBranch(
      password: entered,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      if (res['shopId'] != null) {
        await prefs.setInt('shop_id', res['shopId'] as int);
      } else {
        await prefs.remove('shop_id');
      }
      final shopName = res['shopName']?.toString() ?? 'Outlet';
      await prefs.setString('shop_name', shopName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Verified: Welcome to $shopName'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg = res['message']?.toString() ?? 'Invalid Branch Password or PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sole What Logo
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppConstants.radius5,
                        border: Border.all(color: AppConstants.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        AppConstants.brandLogo,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => const Icon(
                          Icons.local_pizza,
                          size: 50,
                          color: AppConstants.primary,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  const Text(
                    'Sole What Admin',
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Enter your password or PIN to verify and access your shop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 12.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppConstants.cardLight,
                      borderRadius: AppConstants.radius5,
                      border: Border.all(color: AppConstants.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Password / PIN Field Label
                        const Text(
                          'ENTER PASSWORD OR POS PIN',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: _pwdCtrl,
                          obscureText: _obscureText,
                          autofocus: true,
                          style: const TextStyle(
                            color: AppConstants.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Branch Password / Secret PIN',
                            hintStyle: const TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.normal,
                              letterSpacing: 0,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppConstants.primary,
                              size: 19,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility_off : Icons.visibility,
                                color: AppConstants.textMuted,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureText = !_obscureText),
                            ),
                            filled: true,
                            fillColor: AppConstants.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            border: OutlineInputBorder(
                              borderRadius: AppConstants.radius5,
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _handleLogin(),
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: AppConstants.radius5,
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Auto-detects Outlet or Master Admin automatically',
                    style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Developer: Syed Zeeshan Haider',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
