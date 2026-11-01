import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cinematic.dart';
import '../../core/widgets/scene3d.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/document_manager.dart';
import '../../core/l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = context.read<PreferencesService>().aiApiKey;
  }

  @override
  void dispose() { _apiKeyController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    final recentCount = context.watch<DocumentManager>().recentDocs.length;

    return Scaffold(
      backgroundColor: AppTheme.voidBlack,
      body: CinematicBackdrop(child: ContentWidth(child: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 56),
        children: [
          Row(children: [
            Key3D(icon: Icons.arrow_back_rounded, tooltip: tr('Back'), onTap: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 22),
          Padding(padding: EdgeInsets.only(left: 6), child: Kicker(tr('Make it yours')))
              .cinematicIn(delayMs: 60, blur: false),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            // Shrinks on narrow phones and with large system text instead of running off the screen.
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(tr('Your §headline'), style: AppTheme.display(40)),
              GoldText(tr('Settings§headline'), style: AppTheme.display(40, italic: true, weight: FontWeight.w600)),
            ])),
          ).cinematicIn(delayMs: 140),
          const SizedBox(height: 28),

          // ── LANGUAGE ─────────────────────────────────────
          _group(tr('Language'), [
            _SettingsTile(
              icon: Icons.translate_rounded,
              title: tr('Language'),
              subtitle: savedLangChoice().isEmpty ? '${tr('Automatic')} · ${langNames[appLang.value]}' : langNames[appLang.value] ?? 'English',
              onTap: () => _showLanguagePicker(context),
            ),
          ]),

          // ── READING ──────────────────────────────────────
          _group(tr('Reading'), [
            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              title: tr('Night Mode'),
              subtitle: tr('Invert colors for comfortable reading in the dark'),
              trailing: Switch(value: prefs.nightMode, onChanged: (v) => prefs.nightMode = v,
                  activeColor: AppTheme.brandGold),
            ),
            _SettingsTile(
              icon: Icons.bookmark_rounded,
              title: tr('Remember Position'),
              subtitle: tr('Resume reading where you left off'),
              trailing: Switch(value: prefs.rememberPosition, onChanged: (v) => prefs.rememberPosition = v,
                  activeColor: AppTheme.brandGold),
            ),
            _SettingsTile(
              icon: Icons.zoom_in_rounded,
              title: tr('Default Zoom'),
              subtitle: '${(prefs.defaultZoom * 100).toInt()}%',
              onTap: () => _showZoomPicker(context, prefs),
            ),
            _SettingsTile(
              icon: Icons.swap_vert_rounded,
              title: tr('Scroll Direction'),
              subtitle: prefs.scrollDirection == 'vertical' ? tr('Vertical') : tr('Horizontal'),
              onTap: () {
                prefs.scrollDirection = prefs.scrollDirection == 'vertical' ? 'horizontal' : 'vertical';
              },
            ),
            _SettingsTile(
              icon: Icons.view_agenda_rounded,
              title: tr('Page Layout'),
              subtitle: _pageLayoutLabel(prefs.pageLayout),
              onTap: () => _showPageLayoutPicker(context, prefs),
            ),
          ]),

          // ── DISPLAY ──────────────────────────────────────
          _group(tr('Display'), [
            _SettingsTile(
              icon: Icons.format_size_rounded,
              title: tr('Page Spacing'),
              subtitle: tr('{n} px between pages', {'n': prefs.pageSpacing.toInt()}),
              onTap: () => _showSpacingPicker(context, prefs),
            ),
            _SettingsTile(
              icon: Icons.numbers_rounded,
              title: tr('Show Page Count'),
              subtitle: tr('Display page indicator at bottom'),
              trailing: Switch(value: prefs.showPageCount, onChanged: (v) => prefs.showPageCount = v,
                  activeColor: AppTheme.brandGold),
            ),
            _SettingsTile(
              icon: Icons.swipe_rounded,
              title: tr('Show Scroll Head'),
              subtitle: tr('Draggable scroll indicator on the side'),
              trailing: Switch(value: prefs.showScrollHead, onChanged: (v) => prefs.showScrollHead = v,
                  activeColor: AppTheme.brandGold),
            ),
          ]),

          // ── DOCMIND™ AI ──────────────────────────────────
          _group(tr('DocMind™ AI'), [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const AiOrb(size: 64),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Your AI key'), style: AppTheme.display(19)),
                    const SizedBox(height: 3),
                    Text(tr('Stays on this device and is never shared.'),
                        style: AppTheme.body(12.5, color: AppTheme.creamFaint)),
                  ])),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'sk-ant-... or sk-...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontFamily: 'monospace', fontSize: 13),
                    prefixIcon: Icon(Icons.key_rounded, color: AppTheme.brandGold.withValues(alpha: 0.6), size: 18),
                    suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) { _apiKeyController.text = data!.text!; prefs.aiApiKey = data.text!.trim(); }
                        },
                      ),
                    ]),
                  ),
                  onChanged: (v) => prefs.aiApiKey = v.trim(),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(tr('Provider'), style: AppTheme.body(13, color: AppTheme.creamMuted)),
                  Chip3D(label: 'Anthropic', selected: prefs.aiProvider == 'anthropic',
                      onTap: () => prefs.aiProvider = 'anthropic'),
                  Chip3D(label: 'OpenAI', selected: prefs.aiProvider == 'openai',
                      onTap: () => prefs.aiProvider = 'openai'),
                ]),
              ]),
            ),
          ], accent: const Color(0xFF8E7CF0)),

          // ── DATA ─────────────────────────────────────────
          _group(tr('Data'), [
            _SettingsTile(
              icon: Icons.history_rounded,
              title: tr('Recent Documents'),
              subtitle: tr('{n} documents', {'n': recentCount}),
            ),
            _SettingsTile(
              icon: Icons.delete_outline_rounded,
              iconColor: Colors.redAccent,
              title: tr('Clear Recent Documents'),
              subtitle: tr('Remove all reading history'),
              onTap: () => _confirmClear(context),
            ),
          ]),

          // ── ABOUT ────────────────────────────────────────
          _group(tr('About'), [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(children: [
                const BrandMark(size: 52),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Wordmark(size: 22),
                  const SizedBox(height: 4),
                  Text(tr('v{v} · by Martin B', {'v': AppConstants.appVersion}),
                      style: AppTheme.body(12.5, color: AppTheme.creamFaint)),
                  const SizedBox(height: 4),
                  Text(AppConstants.appTagline,
                      style: AppTheme.display(14, italic: true, color: AppTheme.brandGold.withValues(alpha: 0.8))),
                ])),
              ]),
            ),
            if (UpdateService.supported)
              _SettingsTile(icon: Icons.system_update_rounded, title: tr('Check for updates'),
                  subtitle: tr('You have version {v}', {'v': AppConstants.appVersion}),
                  onTap: () async {
                    final updates = context.read<UpdateService>();
                    await updates.check();
                    if (mounted && updates.available == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('ProDFOS is up to date'))));
                    }
                  }),
            _SettingsTile(icon: Icons.forum_outlined, title: tr('Send Feedback'),
                subtitle: tr('Report a bug or suggest an idea'),
                onTap: () => _openLink('https://github.com/fisbal/prodfos/issues/new')),
            _SettingsTile(icon: Icons.privacy_tip_outlined, title: tr('Privacy Policy'),
                subtitle: tr('Your files never leave your device'),
                onTap: () => _openLink('https://fisbal.github.io/prodfos/privacy.html')),
            _SettingsTile(icon: Icons.description_outlined, title: tr('Terms of Service'),
                onTap: () => _openLink('https://fisbal.github.io/prodfos/terms.html')),
            _SettingsTile(icon: Icons.code_rounded, title: tr('Open-source licenses'),
                subtitle: 'pdf.js, Flutter and the libraries ProDFOS uses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersion,
                  applicationLegalese: '© 2026 MartinB',
                )),
          ]),
        ],
      )))),
    );
  }

  Future<void> _openLink(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Could not open {url}', {'url': url}))));
    }
  }

  Widget _group(String title, List<Widget> children, {Color accent = AppTheme.brandGold}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 6, bottom: 10), child: Kicker(title)),
        Slab3D(
          accent: accent,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 70, color: Colors.white.withValues(alpha: 0.05)),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Clear History?')),
        content: Text(tr('This will remove all recent documents from the list. Your PDF files will not be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () {
              context.read<DocumentManager>().clearAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Recent documents cleared'))),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('Clear')),
          ),
        ],
      ),
    );
  }

  String _pageLayoutLabel(String layout) {
    switch (layout) {
      case 'continuous': return tr('Continuous Scroll');
      case 'single': return tr('Single Page');
      case 'facing': return tr('Two Pages Side-by-Side');
      default: return tr('Continuous Scroll');
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final current = savedLangChoice();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(height: 16),
              Text(tr('Language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              for (final code in ['', ...supportedLangs])
                RadioListTile<String>(
                  value: code,
                  groupValue: current,
                  title: Text(code.isEmpty ? tr('Automatic (device or Office In 1)') : langNames[code]!),
                  activeColor: AppTheme.brandGold,
                  onChanged: (v) {
                    Navigator.pop(ctx);
                    setLanguage(v ?? '');
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showZoomPicker(BuildContext context, PreferencesService prefs) {
    final zooms = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            Text(tr('Default Zoom'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...zooms.map((z) => RadioListTile<double>(
              value: z,
              groupValue: prefs.defaultZoom,
              title: Text('${(z * 100).toInt()}%'),
              activeColor: AppTheme.brandGold,
              onChanged: (v) { prefs.defaultZoom = v!; Navigator.pop(ctx); },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPageLayoutPicker(BuildContext context, PreferencesService prefs) {
    final layouts = [
      ('continuous', tr('Continuous Scroll'), Icons.view_agenda_rounded),
      ('single', tr('Single Page'), Icons.crop_portrait_rounded),
      ('facing', tr('Two Pages Side-by-Side'), Icons.menu_book_rounded),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            Text(tr('Page Layout'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...layouts.map((l) => RadioListTile<String>(
              value: l.$1,
              groupValue: prefs.pageLayout,
              title: Text(l.$2),
              secondary: Icon(l.$3),
              activeColor: AppTheme.brandGold,
              onChanged: (v) { prefs.pageLayout = v!; Navigator.pop(ctx); },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSpacingPicker(BuildContext context, PreferencesService prefs) {
    final spacings = [0.0, 2.0, 4.0, 8.0, 16.0];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            Text(tr('Page Spacing'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...spacings.map((s) => RadioListTile<double>(
              value: s,
              groupValue: prefs.pageSpacing,
              title: Text(s == 0 ? tr('No gap') : '${s.toInt()} px'),
              activeColor: AppTheme.brandGold,
              onChanged: (v) { prefs.pageSpacing = v!; Navigator.pop(ctx); },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Widgets ───────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: IconChip3D(icon: icon, color: iconColor ?? AppTheme.brandGold),
      title: Text(title, style: AppTheme.body(15, weight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 13))
          : null,
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2))
          : null),
      onTap: onTap,
    );
  }
}
