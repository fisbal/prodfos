import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cinematic.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  List<FileSystemEntity> _outputFiles = [];

  // ══════════════════════════════════════════════════════════════════
  // LOGIC — unchanged
  // ══════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadOutputFiles();
  }

  Future<void> _loadOutputFiles() async {
    final dir = Directory('/storage/emulated/0/Download/ProDFOS');
    if (await dir.exists()) {
      final files = dir.listSync()..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      if (mounted) setState(() => _outputFiles = files.where((f) => f is File).toList());
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
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

  void _openFile(FileSystemEntity file) {
    final path = file.path;
    final name = path.split('/').last;
    if (name.endsWith('.pdf')) {
      context.push('/viewer?path=${Uri.encodeComponent(path)}');
    } else {
      OpenFilex.open(path);
    }
  }

  void _deleteFile(FileSystemEntity file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${file.path.split('/').last}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              file.deleteSync();
              _loadOutputFiles();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File deleted')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndEdit() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = r?.files.first.path;
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
    final grid = <(IconData, String, String, String)>[
      (Icons.call_merge_rounded, 'Merge', 'Combine PDFs into one', '/tools/merge'),
      (Icons.call_split_rounded, 'Split', 'Extract pages or ranges', '/tools/split'),
      (Icons.text_snippet_rounded, 'Extract Text', 'Pull all text to .txt', '/tools/extract-text'),
      (Icons.photo_library_rounded, 'Images → PDF', 'Photos into a document', '/tools/images-to-pdf'),
      (Icons.edit_document, 'Text → PDF', 'Type it, save it', '/tools/text-to-pdf'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.voidBlack,
      body: CinematicBackdrop(
        child: SafeArea(
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
                    GlassIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: _loadOutputFiles),
                  ]),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Kicker('Craft your documents').cinematicIn(delayMs: 60, blur: false),
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic, children: [
                        Text('PDF ', style: AppTheme.display(40)),
                        GoldText('Tools', style: AppTheme.display(40, italic: true, weight: FontWeight.w600)),
                      ]).cinematicIn(delayMs: 140),
                  ]),
                )),

                // Featured: Edit + Scan
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _featured(
                      icon: Icons.edit_note_rounded, title: 'Edit PDF',
                      subtitle: 'Sign, annotate, fill forms, organize pages',
                      accent: AppTheme.brandGold, onTap: _pickAndEdit)),
                    const SizedBox(width: 12),
                    Expanded(child: _featured(
                      icon: Icons.document_scanner_rounded, title: 'Scan',
                      subtitle: 'Camera to crisp PDF, auto edges',
                      accent: const Color(0xFF4DB6AC), onTap: () => _go('/tools/scan'))),
                  ])),
                ).cinematicIn(delayMs: 240)),

                // Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: grid.length,
                    itemBuilder: (_, i) => GlassCard(
                      radius: 18,
                      padding: const EdgeInsets.all(16),
                      onTap: () => _go(grid[i].$4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(grid[i].$1, size: 24, color: AppTheme.brandGold),
                        const Spacer(),
                        Text(grid[i].$2, style: AppTheme.display(17, height: 1.15)),
                        const SizedBox(height: 4),
                        Text(grid[i].$3, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(11.5, color: AppTheme.creamFaint, height: 1.3)),
                      ]),
                    ).riseIn(i + 2),
                  ),
                ),

                // Created files
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 12),
                  child: Row(children: [
                    const Kicker('Created files'),
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
                    child: Text('Files you create appear here — saved in Downloads/ProDFOS.',
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
        ),
      ),
    );
  }

  Widget _featured({
    required IconData icon, required String title, required String subtitle,
    required Color accent, required VoidCallback onTap,
  }) {
    return GlassCard(
      gold: accent == AppTheme.brandGold,
      radius: 22,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.08)]),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 16)],
          ),
          child: Icon(icon, size: 23, color: accent),
        ),
        const SizedBox(height: 18),
        Text(title, style: AppTheme.display(21)),
        const SizedBox(height: 6),
        Text(subtitle, style: AppTheme.body(12, color: AppTheme.creamFaint, height: 1.35)),
      ]),
    );
  }

  Widget _fileTile(FileSystemEntity file) {
    final name = file.path.split('/').last;
    final stat = file.statSync();
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
            Text('${_formatSize(stat.size)} · ${_timeAgo(stat.modified)}',
                style: AppTheme.body(12, color: AppTheme.creamFaint)),
          ])),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.cream.withValues(alpha: 0.5)),
            onSelected: (a) {
              switch (a) {
                case 'open': _openFile(file);
                case 'share': Share.shareXFiles([XFile(file.path)]);
                case 'delete': _deleteFile(file);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Open')),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ]),
      ),
    );
  }
}
