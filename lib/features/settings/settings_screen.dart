import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cinematic.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/document_manager.dart';

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
    final theme = Theme.of(context);
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      backgroundColor: AppTheme.voidBlack,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CinematicBackdrop(child: ListView(
        children: [
          const SizedBox(height: 8),

          // ── READING ──────────────────────────────────────
          _SectionHeader(title: 'READING'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Night Mode',
            subtitle: 'Invert colors for comfortable reading in the dark',
            trailing: Switch(
              value: prefs.nightMode,
              onChanged: (v) => prefs.nightMode = v,
              activeColor: AppTheme.brandGold,
            ),
          ),
          _SettingsTile(
            icon: Icons.bookmark_rounded,
            title: 'Remember Position',
            subtitle: 'Resume reading where you left off',
            trailing: Switch(
              value: prefs.rememberPosition,
              onChanged: (v) => prefs.rememberPosition = v,
              activeColor: AppTheme.brandGold,
            ),
          ),
          _SettingsTile(
            icon: Icons.zoom_in_rounded,
            title: 'Default Zoom',
            subtitle: '${(prefs.defaultZoom * 100).toInt()}%',
            onTap: () => _showZoomPicker(context, prefs),
          ),
          _SettingsTile(
            icon: Icons.swap_vert_rounded,
            title: 'Scroll Direction',
            subtitle: prefs.scrollDirection == 'vertical' ? 'Vertical' : 'Horizontal',
            onTap: () {
              prefs.scrollDirection =
                  prefs.scrollDirection == 'vertical' ? 'horizontal' : 'vertical';
            },
          ),
          _SettingsTile(
            icon: Icons.view_agenda_rounded,
            title: 'Page Layout',
            subtitle: _pageLayoutLabel(prefs.pageLayout),
            onTap: () => _showPageLayoutPicker(context, prefs),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── DISPLAY ──────────────────────────────────────
          _SectionHeader(title: 'DISPLAY'),
          _SettingsTile(
            icon: Icons.format_size_rounded,
            title: 'Page Spacing',
            subtitle: '${prefs.pageSpacing.toInt()} px between pages',
            onTap: () => _showSpacingPicker(context, prefs),
          ),
          _SettingsTile(
            icon: Icons.numbers_rounded,
            title: 'Show Page Count',
            subtitle: 'Display page indicator at bottom',
            trailing: Switch(
              value: prefs.showPageCount,
              onChanged: (v) => prefs.showPageCount = v,
              activeColor: AppTheme.brandGold,
            ),
          ),
          _SettingsTile(
            icon: Icons.swipe_rounded,
            title: 'Show Scroll Head',
            subtitle: 'Draggable scroll indicator on the side',
            trailing: Switch(
              value: prefs.showScrollHead,
              onChanged: (v) => prefs.showScrollHead = v,
              activeColor: AppTheme.brandGold,
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── DATA ─────────────────────────────────────────
          _SectionHeader(title: 'DATA'),
          _SettingsTile(
            icon: Icons.history_rounded,
            title: 'Recent Documents',
            subtitle: '${context.watch<DocumentManager>().recentDocs.length} documents',
          ),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.red,
            title: 'Clear Recent Documents',
            subtitle: 'Remove all reading history',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History?'),
                  content: const Text('This will remove all recent documents from the list. Your PDF files will not be deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<DocumentManager>().clearAll();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recent documents cleared')),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── DOCMIND™ AI ──────────────────────────────────
          _SectionHeader(title: 'DOCMIND™ AI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  AppTheme.darkCard,
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7), size: 20),
                    SizedBox(width: 8),
                    Text('API Key', style: TextStyle(color: Color(0xFFA29BFE), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Your key stays on-device and is never shared.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'sk-ant-... or sk-...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontFamily: 'monospace', fontSize: 13),
                      prefixIcon: Icon(Icons.key_rounded, color: const Color(0xFF6C5CE7).withValues(alpha: 0.5), size: 18),
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
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('Provider: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Anthropic'), selected: prefs.aiProvider == 'anthropic',
                      selectedColor: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      onSelected: (_) => prefs.aiProvider = 'anthropic'),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('OpenAI'), selected: prefs.aiProvider == 'openai',
                      selectedColor: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      onSelected: (_) => prefs.aiProvider = 'openai'),
                  ]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── COMING SOON ──────────────────────────────────
          _SectionHeader(title: 'COMING SOON'),
          _SettingsTile(
            icon: Icons.draw_rounded,
            title: 'Annotations',
            subtitle: 'Highlight, underline, notes, and stamps',
            trailing: _ComingSoonBadge(),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── ABOUT ────────────────────────────────────────
          _SectionHeader(title: 'ABOUT'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.brandGold.withValues(alpha: 0.06),
                    AppTheme.darkCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.brandGold.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.brandGold, AppTheme.brandGoldLight],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandGold.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('P', style: TextStyle(
                            color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900,
                          )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text.rich(TextSpan(children: [
                              TextSpan(text: 'ProDF', style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 20,
                              )),
                              TextSpan(text: 'OS', style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 20,
                                color: AppTheme.brandGold,
                              )),
                            ])),
                            Text(
                              'v${AppConstants.appVersion} • by Martin B',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appTagline,
                    style: TextStyle(
                      color: AppTheme.brandGold.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.star_outline_rounded,
            title: 'Rate ProDFOS',
            subtitle: 'Love it? Leave a review',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {},
          ),

          const SizedBox(height: 48),
        ],
      )),
    );
  }

  String _pageLayoutLabel(String layout) {
    switch (layout) {
      case 'continuous': return 'Continuous Scroll';
      case 'single': return 'Single Page';
      case 'facing': return 'Two Pages Side-by-Side';
      default: return 'Continuous Scroll';
    }
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
            const Text('Default Zoom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
      ('continuous', 'Continuous Scroll', Icons.view_agenda_rounded),
      ('single', 'Single Page', Icons.crop_portrait_rounded),
      ('facing', 'Two Pages Side-by-Side', Icons.menu_book_rounded),
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
            const Text('Page Layout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
            const Text('Page Spacing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...spacings.map((s) => RadioListTile<double>(
              value: s,
              groupValue: prefs.pageSpacing,
              title: Text(s == 0 ? 'No gap' : '${s.toInt()} px'),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(title, style: TextStyle(
        color: AppTheme.brandGold.withValues(alpha: 0.7),
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.5,
      )),
    );
  }
}

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, size: 22, color: iconColor ?? AppTheme.brandGold.withValues(alpha: 0.7)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
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

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.2)),
      ),
      child: Text('Soon', style: TextStyle(
        color: AppTheme.brandGold.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}
