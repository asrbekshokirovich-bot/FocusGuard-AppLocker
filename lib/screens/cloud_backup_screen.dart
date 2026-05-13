import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/app_translation_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/internet_checker.dart';
import 'premium_screen.dart';

/// "Mening ma'lumotlarim" ekrani — Free/Premium taqqoslash + manual
/// backup tugmasi + sync rejimi (auto/manual) toggle.
class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  String _syncMode = 'auto';
  DateTime? _lastSyncTime;
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isUploading = false;
  BackupProgress? _progress;
  StreamSubscription<BackupProgress>? _progressSub;

  @override
  void initState() {
    super.initState();
    _loadState();
    _progressSub = CloudSyncService.instance.progressStream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final mode = await CloudSyncService.instance.getSyncMode();
    final lastSync = await CloudSyncService.instance.getLastSyncTime();
    final user = FirebaseAuth.instance.currentUser;
    bool premium = false;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache));
        premium = doc.data()?['isPremium'] == true;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _syncMode = mode;
      _lastSyncTime = lastSync;
      _isPremium = premium;
      _isLoading = false;
    });
  }

  Future<void> _changeSyncMode(String mode) async {
    await CloudSyncService.instance.setSyncMode(mode);
    if (!mounted) return;
    setState(() => _syncMode = mode);
  }

  Future<void> _doManualBackup() async {
    // Internet tekshiruv — faqat tugma bosilganda
    if (!await InternetChecker.ensureOnline(context)) return;
    if (!mounted) return;
    setState(() {
      _isUploading = true;
      _progress = null;
    });
    final ok = await CloudSyncService.instance.uploadAllManual();
    if (!mounted) return;
    setState(() => _isUploading = false);
    final lang = AppTranslationService();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (lang.translate('cloud_backup.success') ??
                'Muvaffaqiyatli saqlandi')
            : (lang.translate('cloud_backup.error') ??
                'Saqlashda xatolik yuz berdi')),
        backgroundColor:
            ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    _loadState();
  }

  String _formatLastSync(AppTranslationService lang) {
    if (_lastSyncTime == null) {
      return lang.translate('cloud_backup.never_synced') ?? 'Hech qachon';
    }
    final t = _lastSyncTime!;
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.translate('cloud_backup.title') ?? 'Mening ma\'lumotlarim',
              style: lang.getFont(fontWeight: FontWeight.w800),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(lang),
                      const SizedBox(height: 20),
                      _buildSyncModeToggle(lang),
                      const SizedBox(height: 20),
                      _buildFreePlanCard(lang),
                      const SizedBox(height: 12),
                      _buildPremiumPlanCard(lang),
                      const SizedBox(height: 24),
                      _buildBackupButton(lang),
                      const SizedBox(height: 12),
                      _buildLastSyncInfo(lang),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(AppTranslationService lang) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.cloud_fill,
            color: Color(0xFF007AFF),
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          lang.translate('cloud_backup.header_title') ??
              'Ma\'lumotlarni bulutda saqlang',
          textAlign: TextAlign.center,
          style: lang.getFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lang.translate('cloud_backup.header_desc') ??
              'Yangi telefonga o\'tsangiz ham yo\'qolmasin',
          textAlign: TextAlign.center,
          style: lang.getFont(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncModeToggle(AppTranslationService lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('cloud_backup.sync_mode') ??
                'Sinxronlash rejimi',
            style: lang.getFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          _modeOption(
            value: 'auto',
            title: lang.translate('cloud_backup.mode_auto_title') ??
                'Avtomatik',
            desc: lang.translate('cloud_backup.mode_auto_desc') ??
                'Internet yoqilganda avtomatik saqlanadi',
            icon: CupertinoIcons.wifi,
            lang: lang,
          ),
          const SizedBox(height: 8),
          _modeOption(
            value: 'manual',
            title: lang.translate('cloud_backup.mode_manual_title') ??
                'Qo\'lda',
            desc: lang.translate('cloud_backup.mode_manual_desc') ??
                'Har safar tugma orqali saqlanadi',
            icon: CupertinoIcons.hand_point_right_fill,
            lang: lang,
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
    required String value,
    required String title,
    required String desc,
    required IconData icon,
    required AppTranslationService lang,
  }) {
    final isSelected = _syncMode == value;
    return GestureDetector(
      onTap: () => _changeSyncMode(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF).withOpacity(0.4)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF007AFF)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: lang.getFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: lang.getFont(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF007AFF)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreePlanCard(AppTranslationService lang) {
    final isCurrent = !_isPremium;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF34C759).withOpacity(0.4)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📊',
                style: lang.getFont(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                lang.translate('cloud_backup.free_plan') ?? 'FREE PLAN',
                style: lang.getFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.translate('cloud_backup.current_plan') ?? 'Hozir',
                    style: lang.getFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _planFeature(
              true, lang.translate('cloud_backup.free_streak') ?? 'Streak, XP, Daraja saqlanadi', lang),
          _planFeature(
              true, lang.translate('cloud_backup.free_activities') ?? 'Faoliyatlar ro\'yxati saqlanadi', lang),
          _planFeature(
              true, lang.translate('cloud_backup.free_last7') ?? 'So\'nggi 7 kun calendar saqlanadi', lang),
          _planFeature(
              false, lang.translate('cloud_backup.free_no_old') ?? 'Eski calendar tarixi saqlanmaydi', lang),
          _planFeature(
              false, lang.translate('cloud_backup.free_no_details') ?? 'Sessions/XP tafsilotlari saqlanmaydi', lang),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(AppTranslationService lang) {
    final isCurrent = _isPremium;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFA855F7).withOpacity(0.08),
            const Color(0xFF007AFF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFA855F7).withOpacity(0.5)
              : const Color(0xFFA855F7).withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('✨', style: lang.getFont(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                lang.translate('cloud_backup.premium_plan') ?? 'PREMIUM PLAN',
                style: lang.getFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFA855F7),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.translate('cloud_backup.current_plan') ?? 'Hozir',
                    style: lang.getFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _planFeature(true, lang.translate('cloud_backup.premium_all_free') ?? 'Free Plan\'dagi hammasi +', lang),
          _planFeature(true, lang.translate('cloud_backup.premium_unlimited') ?? 'Cheksiz calendar tarixi', lang),
          _planFeature(true, lang.translate('cloud_backup.premium_breakdown') ?? 'To\'liq activity breakdown (kunlik)', lang),
          _planFeature(true, lang.translate('cloud_backup.premium_sessions') ?? 'Sessions soni va XP detallari', lang),
          _planFeature(true, lang.translate('cloud_backup.premium_multidevice') ?? 'Multi-device sync', lang),
          if (!isCurrent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PremiumScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  lang.translate('cloud_backup.upgrade_btn') ??
                      '👑 Premium\'ga o\'tish',
                  style: lang.getFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planFeature(bool included, String text, AppTranslationService lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.xmark_circle_fill,
            size: 16,
            color: included
                ? const Color(0xFF34C759)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: lang.getFont(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(
                      included ? 0.85 : 0.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupButton(AppTranslationService lang) {
    if (_isUploading) {
      final ratio = _progress?.ratio ?? 0.0;
      final current = _progress?.current ?? 0;
      final total = _progress?.total ?? 0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.translate('cloud_backup.uploading') ??
                        'Ma\'lumotlar yuklanmoqda...',
                    style: lang.getFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$current / $total',
                  style: lang.getFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFF007AFF).withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF007AFF)),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _doManualBackup,
        icon: const Icon(CupertinoIcons.cloud_upload_fill),
        label: Text(
          lang.translate('cloud_backup.upload_btn') ?? 'Bulutga saqlash',
          style: lang.getFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildLastSyncInfo(AppTranslationService lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          CupertinoIcons.clock,
          size: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(width: 6),
        Text(
          '${lang.translate('cloud_backup.last_sync') ?? 'So\'nggi saqlash'}: ${_formatLastSync(lang)}',
          style: lang.getFont(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
