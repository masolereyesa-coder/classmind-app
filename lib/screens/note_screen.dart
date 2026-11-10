import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/note.dart';
import '../l10n/strings.dart';

class NoteScreen extends StatefulWidget {
  final Note note;
  const NoteScreen({super.key, required this.note});
  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _showTranscript = false;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${S.month(d.month)} ${d.year}';
    } catch (_) { return iso.split('T').first; }
  }

  List<_Section> _parseSections(String text) {
    final sections = <_Section>[];
    final lines = text.split('\n');
    String? currentTitle;
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (currentTitle != null) { sections.add(_Section(currentTitle, buffer.toString().trim())); buffer.clear(); }
        currentTitle = line.substring(3).trim();
      } else if (line.startsWith('# ')) {
        // skip H1
      } else if (currentTitle != null) { buffer.writeln(line); }
    }
    if (currentTitle != null) sections.add(_Section(currentTitle, buffer.toString().trim()));
    if (sections.isEmpty && text.isNotEmpty) sections.add(_Section(S.notes, text));
    return sections;
  }

  IconData _sectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('resumen') || t.contains('tema') || t.contains('summary')) return Icons.summarize;
    if (t.contains('concepto') || t.contains('clave') || t.contains('key'))    return Icons.key;
    if (t.contains('desarrollo') || t.contains('contenido'))                   return Icons.article;
    if (t.contains('ejemplo') || t.contains('caso') || t.contains('example'))  return Icons.lightbulb_outline;
    if (t.contains('importante') || t.contains('punto'))                       return Icons.star_outline;
    if (t.contains('pregunta') || t.contains('examen') || t.contains('question')) return Icons.quiz_outlined;
    return Icons.notes;
  }

  Color _sectionColor(int index) {
    const colors = [Color(0xFF6C63FF), Color(0xFF43B89C), Color(0xFFFF6B6B), Color(0xFFFFB84C), Color(0xFF4ECDC4), Color(0xFF7C83FD)];
    return colors[index % colors.length];
  }

  Future<void> _exportTxt() async {
    final sections = _parseSections(widget.note.structuredNotes);
    final buf = StringBuffer();
    buf.writeln('ClassMind — ${widget.note.subjectName}');
    buf.writeln(_formatDate(widget.note.createdAt));
    buf.writeln('=' * 40);
    for (final sec in sections) {
      buf.writeln('\n## ${sec.title}');
      buf.writeln(sec.content);
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/classmind_nota.txt');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path)], subject: 'ClassMind — ${widget.note.subjectName}');
  }

  Future<void> _exportPdf() async {
    final sections = _parseSections(widget.note.structuredNotes);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('ClassMind', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700)),
          pw.SizedBox(height: 4),
          pw.Text(widget.note.subjectName, style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
          pw.Text(_formatDate(widget.note.createdAt), style: pw.TextStyle(fontSize: 12, color: PdfColors.grey500)),
          pw.Divider(color: PdfColors.deepPurple200),
          pw.SizedBox(height: 8),
          for (final sec in sections) ...[
            pw.Text(sec.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700)),
            pw.SizedBox(height: 4),
            pw.Text(sec.content, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/classmind_nota.pdf');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'ClassMind — ${widget.note.subjectName}');
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(widget.note.structuredNotes);
    return Scaffold(
      appBar: AppBar(
        title: Text('${S.classNotes}: ${widget.note.subjectName}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar',
            onSelected: (val) { if (val == 'pdf') _exportPdf(); else _exportTxt(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pdf', child: Row(children: [const Icon(Icons.picture_as_pdf, color: Color(0xFFFF6B6B)), const SizedBox(width: 8), Text(S.exportPdf)])),
              PopupMenuItem(value: 'txt', child: Row(children: [const Icon(Icons.text_snippet, color: Color(0xFF43B89C)), const SizedBox(width: 8), Text(S.exportTxt)])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: S.notes, icon: const Icon(Icons.notes, size: 18)),
            Tab(text: S.info,  icon: const Icon(Icons.info_outline, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            itemBuilder: (ctx, i) {
              final sec   = sections[i];
              final color = _sectionColor(i);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(_sectionIcon(sec.title), color: color, size: 20)),
                    title: Text(sec.title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    initiallyExpanded: i == 0,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SelectableText(sec.content, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(icon: Icons.menu_book,    label: S.subject,   value: widget.note.subjectName),
                const SizedBox(height: 12),
                _InfoCard(icon: Icons.calendar_today, label: S.date,    value: _formatDate(widget.note.createdAt)),
                const SizedBox(height: 12),
                _InfoCard(icon: Icons.timer,         label: S.duration, value: widget.note.duration),
                const SizedBox(height: 20),
                Row(children: [
                  Text(S.transcript, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _showTranscript = !_showTranscript),
                    child: Text(_showTranscript ? S.hide : S.show)),
                ]),
                if (_showTranscript) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(
                      widget.note.transcript.isEmpty ? S.noTranscript : widget.note.transcript,
                      style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white70)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFF6B6B)),
                      label: Text(S.exportPdf, style: const TextStyle(color: Color(0xFFFF6B6B))),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF6B6B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportTxt,
                      icon: const Icon(Icons.text_snippet, color: Color(0xFF43B89C)),
                      label: Text(S.exportTxt, style: const TextStyle(color: Color(0xFF43B89C))),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF43B89C))),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section { final String title; final String content; _Section(this.title, this.content); }

class _InfoCard extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 22),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value,  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
        ]),
      ]),
    );
  }
}
