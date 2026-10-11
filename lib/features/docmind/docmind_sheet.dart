import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/preferences_service.dart';

class DocMindSheet extends StatefulWidget {
  final String filePath;
  const DocMindSheet({super.key, required this.filePath});

  static void show(BuildContext context, String filePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => DocMindSheet(filePath: filePath),
      ),
    );
  }

  @override
  State<DocMindSheet> createState() => _DocMindSheetState();
}

class _DocMindSheetState extends State<DocMindSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  String? _documentText;
  bool _isLoadingText = false;
  String? _textError;

  // Chat
  final List<_ChatMessage> _chatMessages = [];

  // Summary
  String? _summary;
  String _summaryStyle = 'executive';

  // Insights
  String? _insights;

  // PII
  String? _piiResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDocumentText();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentText() async {
    setState(() { _isLoadingText = true; _textError = null; });
    try {
      final text = await context.read<AiService>().extractTextFromPdf(widget.filePath);
      setState(() { _documentText = text; _isLoadingText = false; });
    } catch (e) {
      setState(() { _isLoadingText = false; _textError = e.toString(); });
    }
  }

  String get _apiKey => context.read<PreferencesService>().aiApiKey;
  String get _provider => context.read<PreferencesService>().aiProvider;

  bool get _hasApiKey => _apiKey.isNotEmpty;

  Future<void> _sendChat() async {
    final question = _chatController.text.trim();
    if (question.isEmpty || _documentText == null) return;
    _chatController.clear();

    setState(() => _chatMessages.add(_ChatMessage(role: 'user', text: question)));

    try {
      final history = _chatMessages
          .where((m) => m != _chatMessages.last)
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final answer = await context.read<AiService>().askQuestion(
        documentText: _documentText!,
        question: question,
        apiKey: _apiKey,
        provider: _provider,
        chatHistory: history,
      );
      setState(() => _chatMessages.add(_ChatMessage(role: 'assistant', text: answer)));
    } catch (e) {
      setState(() => _chatMessages.add(_ChatMessage(role: 'error', text: e.toString())));
    }
  }

  Future<void> _generateSummary() async {
    if (_documentText == null) return;
    try {
      final result = await context.read<AiService>().summarize(
        documentText: _documentText!, style: _summaryStyle,
        apiKey: _apiKey, provider: _provider,
      );
      setState(() => _summary = result);
    } catch (e) {
      setState(() => _summary = 'Error: $e');
    }
  }

  Future<void> _generateInsights() async {
    if (_documentText == null) return;
    try {
      final result = await context.read<AiService>().extractInsights(
        documentText: _documentText!, apiKey: _apiKey, provider: _provider,
      );
      setState(() => _insights = result);
    } catch (e) {
      setState(() => _insights = 'Error: $e');
    }
  }

  Future<void> _scanPii() async {
    if (_documentText == null) return;
    try {
      final result = await context.read<AiService>().detectPii(
        documentText: _documentText!, apiKey: _apiKey, provider: _provider,
      );
      setState(() => _piiResult = result);
    } catch (e) {
      setState(() => _piiResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiService = context.watch<AiService>();

    return Column(
      children: [
        // Handle
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('DocMind™', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFFA29BFE),
              )),
              const Spacer(),
              if (aiService.isProcessing)
                Row(children: [
                  const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C5CE7))),
                  const SizedBox(width: 8),
                  Text(aiService.statusMessage ?? 'Working...',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ]),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // API key check
        if (!_hasApiKey) ...[
          _buildNoApiKey(),
        ] else if (_isLoadingText) ...[
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            SizedBox(height: 16),
            Text('Reading document...', style: TextStyle(color: Colors.white54)),
          ]))),
        ] else if (_textError != null) ...[
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(_textError!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.withValues(alpha: 0.7))),
          ))),
        ] else ...[
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFA29BFE),
            unselectedLabelColor: Colors.white38,
            indicatorColor: const Color(0xFF6C5CE7),
            tabs: const [
              Tab(icon: Icon(Icons.chat_rounded, size: 18), text: 'Chat'),
              Tab(icon: Icon(Icons.summarize_rounded, size: 18), text: 'Summary'),
              Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Insights'),
              Tab(icon: Icon(Icons.shield_rounded, size: 18), text: 'PII'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(),
                _buildSummaryTab(),
                _buildInsightsTab(),
                _buildPiiTab(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoApiKey() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key_rounded, size: 48, color: Color(0xFF6C5CE7)),
              const SizedBox(height: 16),
              const Text('API Key Required', style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text('DocMind™ uses your own AI API key.\nGo to Settings to add your Anthropic or OpenAI key.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat Tab ─────────────────────────────────────────
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 40,
                      color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Text('Ask anything about this document',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      _quickChip('What is this about?'),
                      _quickChip('Key takeaways?'),
                      _quickChip('Any deadlines?'),
                    ]),
                  ])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (_, i) => _buildChatBubble(_chatMessages[i]),
                ),
        ),
        // Input — safe above keyboard
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              border: Border(top: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask about this document...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendChat(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendChat,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickChip(String text) {
    return GestureDetector(
      onTap: () { _chatController.text = text; _sendChat(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.25)),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFFA29BFE), fontSize: 12)),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
              : isError ? Colors.red.withValues(alpha: 0.1) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser
                ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                : isError ? Colors.red.withValues(alpha: 0.3) : AppTheme.darkBorder,
          ),
        ),
        child: SelectableText(
          msg.text,
          style: TextStyle(
            fontSize: 14, height: 1.5,
            color: isError ? Colors.red.withValues(alpha: 0.8) : null,
          ),
        ),
      ),
    );
  }

  // ── Summary Tab ──────────────────────────────────────
  Widget _buildSummaryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Style selector
          Wrap(spacing: 8, children: [
            for (final style in ['executive', 'academic', 'casual', 'legal'])
              ChoiceChip(
                label: Text(style[0].toUpperCase() + style.substring(1)),
                selected: _summaryStyle == style,
                selectedColor: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _summaryStyle = style),
              ),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: context.watch<AiService>().isProcessing ? null : _generateSummary,
            icon: const Icon(Icons.summarize_rounded, size: 18),
            label: Text(_summary == null ? 'Generate Summary' : 'Regenerate'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          if (_summary != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_summary!, style: const TextStyle(fontSize: 14, height: 1.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Insights Tab ─────────────────────────────────────
  Widget _buildInsightsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: context.watch<AiService>().isProcessing ? null : _generateInsights,
            icon: const Icon(Icons.insights_rounded, size: 18),
            label: Text(_insights == null ? 'Extract Insights' : 'Re-analyze'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          if (_insights != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_insights!, style: const TextStyle(fontSize: 14, height: 1.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── PII Tab ──────────────────────────────────────────
  Widget _buildPiiTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.shield_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Scans for personal data like names, emails, phone numbers, SSN, etc.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: context.watch<AiService>().isProcessing ? null : _scanPii,
            icon: const Icon(Icons.security_rounded, size: 18),
            label: Text(_piiResult == null ? 'Scan for PII' : 'Rescan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          if (_piiResult != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_piiResult!, style: const TextStyle(fontSize: 14, height: 1.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role; // 'user', 'assistant', 'error'
  final String text;
  _ChatMessage({required this.role, required this.text});
}
