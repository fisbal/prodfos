import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/platform/app_files.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cinematic.dart';
import '../../core/widgets/scene3d.dart';
import '../../core/l10n/l10n.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  List<StoredFile> _outputFiles = [];

  // ══════════════════════════════════════════════════════════════════
  // LOGIC — unchanged
  // ══════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadOutputFiles();
  }

  Future<void> _loadOutputFiles() async {
    try {
      final files = await AppFiles.listOutputs();
      if (mounted) setState(() => _outputFiles = files);
    } catch (_) {}
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return tr('just now');
    if (diff.inMinutes < 60) return tr('{n}m ago', {'n': diff.inMinutes});
    if (diff.inHours < 24) return tr('{n}h ago', {'n': diff.inHours});
    if (diff.inDays < 7) return tr('{n}d ago', {'n': diff.inDays});
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _iconForFile(String name) {
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.endsWith('.txt')) return Icons.text_snippet_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _colorForFile(String name) {
    if (name.endsWith('.pdf')) return AppTheme.brandGold;
    if (name.endsWith('.txt')) return const Color(0xFFB39DDB);
    return Colors.grey;
  }

  void _openFile(StoredFile file) {
    if (file.name.toLowerCase().endsWith('.pdf')) {
      context.push('/viewer?path=${Uri.encodeComponent(file.path)}');
    } else {
      AppFiles.open(file.path);
    }
  }

  void _deleteFile(StoredFile file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete file?')),
        content: Text(tr('Delete "{name}"? This cannot be undone.', {'name': file.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppFiles.delete(file.path);
              await _loadOutputFiles();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('File deleted'))),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndEdit() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: AppFiles.pickWithData);
    if (r == null || r.files.isEmpty) return;
    final path = await AppFiles.fromPicked(r.files.first);
    if (path == null || !mounted) return;
    await context.push('/editor?path=${Uri.encodeComponent(path)}');
    _loadOutputFiles();
  }

  Future<void> _go(String route) async {
    await context.push(route);
    _loadOutputFiles();
  }

  // ══════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final grid = <(Scene, String, String, String)>[
      (Scene.merge, tr('Merge'), tr('Combine PDFs into one'), '/tools/merge'),
      (Scene.split, tr('Split'), tr('Extract pages or ranges'), '/tools/split'),
      (Scene.extract, tr('Extract Text'), tr('Pull all text to .txt'), '/tools/extract-text'),
      (Scene.images, tr('Images to PDF'), tr('Photos into a document'), '/tools/images-to-pdf'),
      (Scene.text, tr('Text to PDF'), tr('Type it, save it'), '/tools/text-to-pdf'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.voidBlack,
      body: CinematicBackdrop(
        child: ContentWidth(child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.brandGold,
            onRefresh: _loadOutputFiles,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Header
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
                    const Spacer(),
                    GlassIconButton(icon: Icons.refresh_rounded, tooltip: tr('Refresh'), onTap: _loadOutputFiles),
                  ]),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Kicker(tr('Craft your documents')).cinematicIn(delayMs: 60, blur: false),
                    const SizedBox(height: 10),
                    // Shrinks on narrow phones and with large system text instead of running off the screen.
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic, children: [
                        Text(tr('PDF §headline'), style: AppTheme.display(40)),
                        GoldText(tr('Tools§headline'), style: AppTheme.display(40, italic: true, weight: FontWeight.w600)),
                      ])).cinematicIn(delayMs: 140),
                  ]),
                )),

                // Featured: Edit + Scan
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: SceneTile(
                      scene: Scene.edit, label: tr('Edit PDF'), large: true, sceneHeight: 96,
                      subtitle: tr('Sign, annotate, fill forms, organize pages'),
                      onTap: _pickAndEdit)),
                    const SizedBox(width: 12),
                    Expanded(child: SceneTile(
                      scene: Scene.scan, label: tr('Scan'), large: true, sceneHeight: 96,
                      subtitle: tr('Camera to crisp PDF, auto edges'),
                      accent: const Color(0xFF4DB6AC), onTap: () => _go('/tools/scan'))),
                  ])),
                ).cinematicIn(delayMs: 240)),

                // Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12,
                      mainAxisExtent: 236, // room for a two-line name and a three-line description in every language
                    ),
                    itemCount: grid.length,
                    itemBuilder: (_, i) => SceneTile(
                      scene: grid[i].$1, label: grid[i].$2, subtitle: grid[i].$3,
                      large: true, sceneHeight: 78,
                      onTap: () => _go(grid[i].$4),
                    ).riseIn(i + 2),
                  ),
                ),

                // Created files
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 12),
                  child: Row(children: [
                    Kicker(tr('Created files')),
                    const SizedBox(width: 8),
                    if (_outputFiles.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.brandGold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_outputFiles.length}',
                            style: AppTheme.body(11, weight: FontWeight.w700, color: AppTheme.brandGold)),
                      ),
                  ]),
                )),
                if (_outputFiles.isEmpty)
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Text(AppFiles.isWeb
                        ? tr('Files you create appear here — kept in this browser. Use ⋮ → Download to save them to your computer.')
                        : tr('Files you create appear here — saved in {place}.', {'place': _savedIn()}),
                        style: AppTheme.body(13, color: AppTheme.creamFaint, height: 1.4)),
                  ))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: _outputFiles.length,
                      itemBuilder: (_, i) => _fileTile(_outputFiles[i]),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        )),
      ),
    );
  }

  String _savedIn() =>
      Theme.of(context).platform == TargetPlatform.android ? 'Downloads/ProDFOS' : 'Documents\\ProDFOS';

  Widget _fileTile(StoredFile file) {
    final name = file.name;
    final color = _colorForFile(name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        onTap: () => _openFile(file),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_iconForFile(name), size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTheme.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${_formatSize(file.size)} · ${_timeAgo(file.modified)}',
                style: AppTheme.body(12, color: AppTheme.creamFaint)),
          ])),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.cream.withValues(alpha: 0.5)),
            onSelected: (a) {
              switch (a) {
                case 'open': _openFile(file);
                case 'share': AppFiles.share(file.path);
                case 'delete': _deleteFile(file);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'open', child: Text(tr('Open'))),
              PopupMenuItem(value: 'share', child: Text(AppFiles.isWeb ? tr('Download') : tr('Share'))),
              PopupMenuItem(value: 'delete', child: Text(tr('Delete'), style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ]),
      ),
    );
  }
}
