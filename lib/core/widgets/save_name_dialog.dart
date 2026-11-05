import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../platform/app_files.dart';

/// Before saving a file: its name (editable, proposed as [proposed]) and where it goes ([folder], in words),
/// with the choice to also save a copy anywhere. Like Adobe Scan and Word's "Save as".
Future<({String name, bool elsewhere})?> askSaveNameAndPlace(BuildContext context,
        {required String folder, required String proposed, required String title}) =>
    showDialog<({String name, bool elsewhere})>(context: context,
        builder: (_) => _SaveNameDialog(folder: folder, proposed: proposed, title: title));

class _SaveNameDialog extends StatefulWidget {
  const _SaveNameDialog({required this.folder, required this.proposed, required this.title});
  final String folder, proposed, title;
  @override
  State<_SaveNameDialog> createState() => _SaveNameDialogState();
}

class _SaveNameDialogState extends State<_SaveNameDialog> {
  late final _name = TextEditingController(text: widget.proposed);
  bool _elsewhere = false;

  @override
  void initState() {
    super.initState();
    _name.selection = TextSelection(baseOffset: 0, extentOffset: _name.text.length);
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _save() => Navigator.pop(context, (name: _name.text, elsewhere: _elsewhere));

  @override
  Widget build(BuildContext context) => AlertDialog(
    // Phones held sideways are only about 390 px high: the whole dialog scrolls, never the choices alone.
    scrollable: true,
    title: Text(widget.title),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        key: const Key('save-name'), controller: _name, autofocus: true,
        decoration: InputDecoration(labelText: tr('File name'), suffixText: '.pdf', prefixIcon: const Icon(Icons.picture_as_pdf_rounded)),
        onSubmitted: (_) => _save(),
      ),
      const SizedBox(height: 16),
      Text(tr('Where'), style: const TextStyle(fontWeight: FontWeight.w600)),
      RadioGroup<bool>(
        groupValue: _elsewhere,
        onChanged: (v) => setState(() => _elsewhere = v ?? false),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<bool>(
            key: const Key('save-place-prodfos'), value: false, contentPadding: EdgeInsets.zero,
            title: Text(tr('ProDFOS folder')), subtitle: Text(widget.folder),
          ),
          if (AppFiles.canChoosePlace)
            RadioListTile<bool>(
              key: const Key('save-place-other'), value: true, contentPadding: EdgeInsets.zero,
              title: Text(AppFiles.isWeb ? tr('Also download a copy') : tr('Also save a copy elsewhere…')),
              subtitle: Text(AppFiles.isWeb ? tr('Your browser saves it in Downloads') : tr('Any folder, SD card or Drive')),
            ),
        ]),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
      FilledButton.icon(key: const Key('save-ok'), onPressed: _save, icon: const Icon(Icons.save_rounded, size: 18), label: Text(tr('Save'))),
    ],
  );
}
