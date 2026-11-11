import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_update_service.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;
  String? _checkError;

  bool _aiWhatsAppEnabled = true;
  bool _autoRiderAlert = true;
  bool _autoCustomerAlert = true;

  int? _shopId;
  String _shopName = 'SoleWhat';
  final TextEditingController _testPhoneCtrl = TextEditingController();
  bool _isSendingTestMsg = false;
  String? _testMsgStatus;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkUpdatesOnLoad();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopId = prefs.getInt('shop_id');
      _shopName = prefs.getString('shop_name') ?? 'SoleWhat';
      _aiWhatsAppEnabled = prefs.getBool('ai_whatsapp_enabled') ?? true;
      _autoRiderAlert = prefs.getBool('auto_rider_alert') ?? true;
      _autoCustomerAlert = prefs.getBool('auto_customer_alert') ?? true;
    });
  }

  Future<void> _savePref(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  Future<void> _checkUpdatesOnLoad() async {
    setState(() {
      _isCheckingUpdate = true;
      _checkError = null;
    });

    try {
      final info = await AppUpdateService.instance.checkForUpdate();
      if (mounted) {
        setState(() {
          _updateInfo = info;
          _isCheckingUpdate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = 'Could not reach GitHub Releases';
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _handleDownloadUpdate() async {
    final rawUrl = _updateInfo?.downloadUrl ?? 'https://github.com/bhaijew/appsolewhat/releases/latest';
    final ok = await AppUpdateService.instance.launchDownload(rawUrl);
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download link copied to clipboard: $rawUrl'),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _sendTestWhatsAppMessage() async {
    final phone = _testPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number to test')),
      );
      return;
    }

    setState(() {
      _isSendingTestMsg = true;
      _testMsgStatus = null;
    });

    final res = await SupabaseService.instance.sendWhatsAppMessage(
      toPhone: phone,
      message: 'Salam! 🍕 This is a test message from SoleWhat AI Automation system.',
      shopId: _shopId,
    );

    setState(() {
      _isSendingTestMsg = false;
      _testMsgStatus = res['success'] == true
          ? '✓ WhatsApp message sent successfully!'
          : 'Failed: ${res['error'] ?? 'Unknown error'}';
    });
  }

  Future<void> _sendTestCounterPrint(String type) async {
    final success = await SupabaseService.instance.triggerCounterPrint(
      0, // test tag
      type: type,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test $type print request dispatched to Counter POS!'
                : 'Failed to send test print',
          ),
          backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = _updateInfo?.hasUpdate == true;

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        backgroundColor: AppConstants.cardLight,
        elevation: 0,
        title: const Text(
          'Settings & Updates',
          style: TextStyle(
            color: AppConstants.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. GITHUB AUTO UPDATE CARD ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(
                  color: hasUpdate ? Colors.green : AppConstants.borderLight,
                  width: hasUpdate ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasUpdate ? Colors.green : Colors.black).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.system_update, color: AppConstants.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'APP VERSION & GITHUB UPDATE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (_isCheckingUpdate)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Installed Version',
                            style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'v${AppUpdateService.currentAppVersion}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppConstants.textDark,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Check Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.surfaceLight,
                          foregroundColor: AppConstants.textDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                        ),
                        onPressed: _isCheckingUpdate ? null : _checkUpdatesOnLoad,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasUpdate) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: AppConstants.radius5,
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'New Version Available: v${_updateInfo!.latestVersion}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_updateInfo!.releaseNotes != null && _updateInfo!.releaseNotes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _updateInfo!.releaseNotes!,
                              style: const TextStyle(fontSize: 11, color: AppConstants.textBody),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text(
                                'DOWNLOAD & INSTALL UPDATE',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                              ),
                              onPressed: _handleDownloadUpdate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceLight,
                        borderRadius: AppConstants.radius5,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.verified, color: Colors.teal, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'App is up to date with latest GitHub release.',
                              style: TextStyle(fontSize: 11.5, color: AppConstants.textBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_checkError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_checkError!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. SOLEWHAT AI REAL-TIME WHATSAPP AUTOMATION ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.teal, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'SOLEWHAT AI WHATSAPP AUTOMATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Enable Real-Time AI Automation',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Automatically dispatches WhatsApp updates to customers & riders',
                        style: TextStyle(fontSize: 11, color: AppConstants.textMuted)),
                    value: _aiWhatsAppEnabled,
                    activeThumbColor: Colors.teal,
                    onChanged: (val) {
                      setState(() => _aiWhatsAppEnabled = val);
                      _savePref('ai_whatsapp_enabled', val);
                    },
                  ),
                  const Divider(height: 16, color: AppConstants.borderLight),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Customer Dispatch Message', style: TextStyle(fontSize: 12)),
                    subtitle: const Text('Send live tracking & rider details to customer on dispatch',
                        style: TextStyle(fontSize: 10.5, color: AppConstants.textMuted)),
                    value: _autoCustomerAlert,
                    activeThumbColor: Colors.teal,
                    onChanged: _aiWhatsAppEnabled
                        ? (val) {
                            setState(() => _autoCustomerAlert = val);
                            _savePref('auto_customer_alert', val);
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Rider Task Message', style: TextStyle(fontSize: 12)),
                    subtitle: const Text('Send order address, contact & bill amount directly to rider WhatsApp',
                        style: TextStyle(fontSize: 10.5, color: AppConstants.textMuted)),
                    value: _autoRiderAlert,
                    activeThumbColor: Colors.teal,
                    onChanged: _aiWhatsAppEnabled
                        ? (val) {
                            setState(() => _autoRiderAlert = val);
                            _savePref('auto_rider_alert', val);
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  // Test Message Sender
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceLight,
                      borderRadius: AppConstants.radius5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TEST WHATSAPP GATEWAY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.textMuted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _testPhoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  hintText: 'Enter phone (e.g. 03001234567)',
                                  hintStyle: TextStyle(fontSize: 11),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                              ),
                              onPressed: _isSendingTestMsg ? null : _sendTestWhatsAppMessage,
                              child: _isSendingTestMsg
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Send Test', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ],
                        ),
                        if (_testMsgStatus != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _testMsgStatus!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _testMsgStatus!.startsWith('✓') ? Colors.green.shade800 : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 3. COUNTER POS THERMAL PRINTER (OPTION A) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.print, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'COUNTER POS PRINTER (OPTION A)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'When you press "Customer Bill" or "Kitchen KOT", a print command is dispatched via Supabase Realtime to the counter FloDesktop POS machine attached to the printer.',
                    style: TextStyle(fontSize: 11.5, color: AppConstants.textBody),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.receipt, size: 14),
                          label: const Text('Test Bill Print', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.primary,
                            side: const BorderSide(color: AppConstants.primary),
                            shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                          ),
                          onPressed: () => _sendTestCounterPrint('bill'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.soup_kitchen, size: 14),
                          label: const Text('Test KOT Print', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            shape: RoundedRectangleBorder(borderRadius: AppConstants.radius5),
                          ),
                          onPressed: () => _sendTestCounterPrint('kot'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 4. BRANCH & DEVELOPER INFO ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardLight,
                borderRadius: AppConstants.radius5,
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Branch',
                        style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
                      ),
                      Text(
                        _shopName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Branch ID',
                        style: TextStyle(fontSize: 12, color: AppConstants.textMuted),
                      ),
                      Text(
                        _shopId != null ? '#$_shopId' : 'Master Outlet',
                        style: const TextStyle(fontSize: 12, color: AppConstants.textDark),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppConstants.borderLight),
                  const Center(
                    child: Text(
                      'Developer: Syed Zeeshan Haider',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
