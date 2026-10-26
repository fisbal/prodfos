import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import '../platform/app_files.dart';

/// DocMind™ AI Engine — sends PDF text to Anthropic/OpenAI for analysis.
class AiService extends ChangeNotifier {
  bool _isProcessing = false;
  String? _statusMessage;

  bool get isProcessing => _isProcessing;
  String? get statusMessage => _statusMessage;

  /// Extract text from a PDF file for AI context.
  Future<String> extractTextFromPdf(String filePath) async {
    final bytes = await AppFiles.readBytes(filePath);
    final doc = sync_pdf.PdfDocument(inputBytes: bytes);
    final buffer = StringBuffer();
    final extractor = sync_pdf.PdfTextExtractor(doc);

    for (int i = 0; i < doc.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (text.trim().isNotEmpty) {
        buffer.writeln('[Page ${i + 1}]');
        buffer.writeln(text.trim());
        buffer.writeln();
      }
    }
    doc.dispose();

    final result = buffer.toString();
    if (result.trim().isEmpty) {
      throw Exception('No text found in this PDF. It may be a scanned image.');
    }
    return result;
  }

  /// Ask a question about the document.
  Future<String> askQuestion({
    required String documentText,
    required String question,
    required String apiKey,
    required String provider, // 'anthropic' or 'openai'
    List<Map<String, String>>? chatHistory,
  }) async {
    _setStatus('Thinking...');
    try {
      final systemPrompt = '''You are DocMind™, an intelligent document assistant built into ProDFOS.
You have access to the full text of the user's PDF document.
Answer questions accurately based on the document content.
If the answer isn't in the document, say so clearly.
Be concise but thorough. Use specific page references when possible.
Format your response with clear structure.''';

      final contextMsg = 'Here is the document text:\n\n$documentText';

      final result = await _callApi(
        systemPrompt: systemPrompt,
        messages: [
          {'role': 'user', 'content': contextMsg},
          if (chatHistory != null) ...chatHistory,
          {'role': 'user', 'content': question},
        ],
        apiKey: apiKey,
        provider: provider,
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      rethrow;
    }
  }

  /// Generate a summary of the document.
  Future<String> summarize({
    required String documentText,
    required String style, // 'executive', 'academic', 'casual', 'legal'
    required String apiKey,
    required String provider,
  }) async {
    _setStatus('Generating summary...');
    try {
      final styleInstructions = {
        'executive': 'Write a concise executive summary. Focus on key findings, decisions, and action items. Use bullet points. Keep it under 300 words.',
        'academic': 'Write a scholarly summary. Include methodology, key arguments, findings, and conclusions. Cite specific sections.',
        'casual': 'Explain what this document is about in plain, everyday language. Like explaining it to a friend. Keep it simple and clear.',
        'legal': 'Provide a legal summary highlighting obligations, rights, deadlines, parties involved, and key clauses. Flag any risks.',
      };

      final result = await _callApi(
        systemPrompt: 'You are DocMind™, a document analysis AI. Summarize the following document.',
        messages: [
          {'role': 'user', 'content': 'Document text:\n\n$documentText\n\nInstruction: ${styleInstructions[style] ?? styleInstructions['executive']!}'},
        ],
        apiKey: apiKey,
        provider: provider,
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      rethrow;
    }
  }

  /// Extract key facts and entities from the document.
  Future<String> extractInsights({
    required String documentText,
    required String apiKey,
    required String provider,
  }) async {
    _setStatus('Analyzing document...');
    try {
      final result = await _callApi(
        systemPrompt: 'You are DocMind™, a document analysis AI.',
        messages: [
          {'role': 'user', 'content': '''Analyze this document and extract:

1. **Key Facts** — The most important facts stated in the document
2. **People & Organizations** — Names of people, companies, institutions mentioned
3. **Dates & Deadlines** — Any dates, deadlines, or time references
4. **Amounts & Numbers** — Financial figures, quantities, percentages
5. **Locations** — Places, addresses, regions mentioned
6. **Action Items** — Tasks, requirements, or next steps

Document text:
$documentText'''},
        ],
        apiKey: apiKey,
        provider: provider,
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      rethrow;
    }
  }

  /// Detect PII (personally identifiable information) in the document.
  Future<String> detectPii({
    required String documentText,
    required String apiKey,
    required String provider,
  }) async {
    _setStatus('Scanning for PII...');
    try {
      final result = await _callApi(
        systemPrompt: 'You are DocMind™, a privacy analysis AI.',
        messages: [
          {'role': 'user', 'content': '''Scan this document for Personally Identifiable Information (PII).

Look for:
- Full names
- Email addresses
- Phone numbers
- Physical addresses
- Social Security / Insurance numbers
- Bank account / credit card numbers
- Dates of birth
- Passport / ID numbers
- Medical information
- Any other sensitive personal data

For each item found, state:
- **Type** of PII
- **Value** found (partially redacted for safety)
- **Page/location** in document
- **Risk level** (High / Medium / Low)

Document text:
$documentText'''},
        ],
        apiKey: apiKey,
        provider: provider,
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      rethrow;
    }
  }

  // ── API Call ─────────────────────────────────────────────
  Future<String> _callApi({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required String apiKey,
    required String provider,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('No API key set. Go to Settings to add your Anthropic or OpenAI key.');
    }

    if (provider == 'anthropic') {
      return _callAnthropic(systemPrompt, messages, apiKey);
    } else {
      return _callOpenAI(systemPrompt, messages, apiKey);
    }
  }

  Future<String> _callAnthropic(String system, List<Map<String, String>> messages, String apiKey) async {
    // Trim any whitespace/newlines from key
    final cleanKey = apiKey.trim().replaceAll('\n', '').replaceAll('\r', '');
    
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': cleanKey,
        'anthropic-version': '2023-06-01',
        // Required when ProDFOS runs in a browser (GitHub Pages link)
        'anthropic-dangerous-direct-browser-access': 'true',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-opus-5-5',
        'max_tokens': 4096,
        'system': system,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      // Show full error for debugging
      String errorMsg;
      try {
        final body = jsonDecode(response.body);
        errorMsg = 'Status ${response.statusCode}: ${body['error']?['message'] ?? body['error']?['type'] ?? response.body}';
      } catch (_) {
        errorMsg = 'Status ${response.statusCode}: ${response.body}';
      }
      throw Exception(errorMsg);
    }

    final body = jsonDecode(response.body);
    final content = body['content'] as List;
    return content.map((c) => c['text'] ?? '').join('\n');
  }

  Future<String> _callOpenAI(String system, List<Map<String, String>> messages, String apiKey) async {
    // Convert to OpenAI format
    final openaiMessages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...messages,
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': openaiMessages,
        'max_tokens': 4096,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception('OpenAI API error: ${body['error']?['message'] ?? response.statusCode}');
    }

    final body = jsonDecode(response.body);
    return body['choices'][0]['message']['content'] ?? '';
  }

  void _setStatus(String msg) { _isProcessing = true; _statusMessage = msg; notifyListeners(); }
  void _clearStatus() { _isProcessing = false; _statusMessage = null; notifyListeners(); }
}
