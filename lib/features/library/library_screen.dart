import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cinematic.dart';
import '../../core/services/document_manager.dart';
import '../viewer/viewer_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // ── Logic (same behavior as Phase 1) ─────────────────────
  Future<void> _openFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
      allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String? filePath;
    try { filePath = file.path; } catch (_) { filePath = null; }

    if (filePath != null && filePath.isNotEmpty) {
      final fileName = filePath.split(RegExp(r'[/\\]')).last;
      if (!mounted) return;
      context.read<DocumentManager>().addToRecent(filePath, fileName);
      context.push('/viewer?path=${Uri.encodeComponent(filePath)}');
    } else if (file.bytes != null && mounted) {
      ViewerScreen.webBytes = file.bytes;
      ViewerScreen.webFileName = file.name;
      context.push('/viewer?path=web-memory');
    }
  }

  Future<void> _pickAndEdit() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = r?.files.first.path;
    if (path == null || !mounted) return;
    context.push('/editor?path=${Uri.encodeComponent(path)}');
  }

  void _openRecent(DocumentManager dm, RecentDoc doc) {
    dm.addToRecent(doc.filePath, doc.fileName); // bumps to top, keeps page
    context.push('/viewer?path=${Uri.encodeComponent(doc.filePath)}');
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DocumentManager>();
    final docs = dm.recentDocs;

    return Scaffold(
      backgroundColor: AppTheme.voidBlack,
      extendBody: true,
      body: CinematicBackdrop(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _quickTools()),
              if (docs.isEmpty)
                SliverToBoxAdapter(child: _emptyState())
              else ...[
                SliverToBoxAdapter(child: _continueCard(dm, docs.first)),
                if (docs.length > 1) ...[
                  const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 30, 24, 12),
                    child: Kicker('Recent'),
                  )),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: docs.length - 1,
                      itemBuilder: (_, i) => _recentTile(dm, docs[i + 1]).riseIn(i),
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GlassNavBar(current: 0, items: [
        GlassNavItem(Icons.auto_stories_rounded, 'Library', () {}),
        GlassNavItem(Icons.widgets_rounded, 'Tools', () => context.push('/tools')),
        GlassNavItem(Icons.tune_rounded, 'Settings', () => context.push('/settings')),
      ]),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 0),
      child: Row(children: [
        const BrandMark(size: 38),
        const SizedBox(width: 12),
        const Wordmark(size: 24),
        const Spacer(),
        GlassIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onTap: () => context.push('/settings'),
        ),
      ]),
    ).cinematicIn(blur: false);
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting, style: AppTheme.body(14, color: AppTheme.creamMuted, letterSpacing: 0.3))
            .cinematicIn(delayMs: 100),
        const SizedBox(height: 10),
        Text('Read smarter.', style: AppTheme.display(42, height: 1.05))
            .cinematicIn(delayMs: 200),
        GoldText('Not harder.',
            style: AppTheme.display(42, italic: true, weight: FontWeight.w600, height: 1.15))
            .cinematicIn(delayMs: 330),
        const SizedBox(height: 14),
        Text('Your documents, understood by DocMind™ AI.',
            style: AppTheme.body(14.5, color: AppTheme.creamFaint, height: 1.4))
            .cinematicIn(delayMs: 450),
        const SizedBox(height: 28),
        Wrap(spacing: 12, runSpacing: 12, children: [
          GoldPillButton(label: 'Open PDF', icon: Icons.add_rounded, onTap: _openFilePicker),
          GlassPillButton(label: 'Scan', icon: Icons.document_scanner_rounded,
              onTap: () => context.push('/tools/scan')),
        ]).cinematicIn(delayMs: 560),
      ]),
    );
  }

  Widget _quickTools() {
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.edit_note_rounded, 'Edit', _pickAndEdit),
      (Icons.call_merge_rounded, 'Merge', () => context.push('/tools/merge')),
      (Icons.call_split_rounded, 'Split', () => context.push('/tools/split')),
      (Icons.widgets_rounded, 'All tools', () => context.push('/tools')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Row(children: [
        for (int i = 0; i < tools.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: GlassCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: tools[i].$3,
            child: Column(children: [
              Icon(tools[i].$1, size: 22, color: AppTheme.brandGold),
              const SizedBox(height: 6),
              Text(tools[i].$2, maxLines: 1, style: AppTheme.body(11.5, weight: FontWeight.w600,
                  color: AppTheme.cream.withValues(alpha: 0.8))),
            ]),
          )),
        ],
      ]),
    ).cinematicIn(delayMs: 650, blur: false);
  }

  Widget _continueCard(DocumentManager dm, RecentDoc doc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(left: 4, bottom: 12), child: Kicker('Continue reading')),
        GlassCard(
          gold: true,
          radius: 22,
          padding: const EdgeInsets.all(18),
          onTap: () => _openRecent(dm, doc),
          child: Row(children: [
            Container(
              width: 58, height: 74,
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Stack(children: [
                Positioned(left: 9, right: 9, top: 12, child: Container(height: 3,
                    color: AppTheme.brandGold.withValues(alpha: 0.8))),
                for (int k = 0; k < 5; k++)
                  Positioned(left: 9, right: k.isEven ? 9 : 20, top: 22.0 + k * 8,
                      child: Container(height: 2, color: Colors.black.withValues(alpha: 0.15))),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(19, height: 1.2)),
              const SizedBox(height: 8),
              Text('Page ${doc.lastPage} · ${_timeAgo(doc.openedAt)}',
                  style: AppTheme.body(12.5, color: AppTheme.creamFaint)),
            ])),
            const SizedBox(width: 10),
            Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.goldGradient),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
            ),
          ]),
        ),
      ]),
    ).cinematicIn(delayMs: 760);
  }

  Widget _recentTile(DocumentManager dm, RecentDoc doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => _openRecent(dm, doc),
        child: Row(children: [
          Container(
            width: 40, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(Icons.description_rounded, size: 20,
                color: AppTheme.brandGold.withValues(alpha: 0.75)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTheme.body(14.5, weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('Page ${doc.lastPage} · ${_timeAgo(doc.openedAt)}',
                style: AppTheme.body(12, color: AppTheme.creamFaint)),
          ])),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.cream.withValues(alpha: 0.3)),
            tooltip: 'Remove from recents',
            onPressed: () => dm.removeFromRecent(doc.filePath),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: Column(children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.goldHairline),
            gradient: RadialGradient(colors: [
              AppTheme.brandGold.withValues(alpha: 0.14), Colors.transparent,
            ]),
          ),
          child: Icon(Icons.auto_stories_rounded, size: 32,
              color: AppTheme.brandGold.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 22),
        Text('Your library is quiet.',
            style: AppTheme.display(24, italic: true, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('Open or scan a document to begin.',
            style: AppTheme.body(14, color: AppTheme.creamFaint)),
      ]),
    ).cinematicIn(delayMs: 700);
  }
}
