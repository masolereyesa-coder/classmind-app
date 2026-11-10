import 'package:flutter/material.dart';
import '../models/note.dart';

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
      const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      return '\${d.day} de \${months[d.month]} \${d.year}';
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
    if (sections.isEmpty && text.isNotEmpty) sections.add(_Section('Contenido', text));
    return sections;
  }

  IconData _sectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('resumen') || t.contains('tema')) return Icons.summarize;
    if (t.contains('concepto') || t.contains('clave')) return Icons.key;
    if (t.contains('desarrollo') || t.contains('contenido')) return Icons.article;
    if (t.contains('ejemplo') || t.contains('caso')) return Icons.lightbulb_outline;
    if (t.contains('importante') || t.contains('punto')) return Icons.star_outline;
    if (t.contains('pregunta') || t.contains('examen')) return Icons.quiz_outlined;
    return Icons.notes;
  }

  Color _sectionColor(int index) {
    const colors = [Color(0xFF6C63FF), Color(0xFF43B89C), Color(0xFFFF6B6B), Color(0xFFFFB84C), Color(0xFF4ECDC4), Color(0xFF7C83FD)];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(widget.note.structuredNotes);
    return Scaffold(
      appBar: AppBar(
        title: Text('Clase: \${widget.note.subjectName}'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Notas', icon: Icon(Icons.notes, size: 18)),
            Tab(text: 'Info', icon: Icon(Icons.info_outline, size: 18)),
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
              final sec = sections[i];
              final color = _sectionColor(i);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(_sectionIcon(sec.title), color: color, size: 20),
                    ),
                    title: Text(sec.title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    initiallyExpanded: i == 0,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SelectableText(sec.content, style: const TextStyle(fontSize: 14, height: 1.6)),
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
                _InfoCard(icon: Icons.menu_book, label: 'Materia', value: widget.note.subjectName),
                const SizedBox(height: 12),
                _InfoCard(icon: Icons.calendar_today, label: 'Fecha', value: _formatDate(widget.note.createdAt)),
                const SizedBox(height: 12),
                _InfoCard(icon: Icons.timer, label: 'Duracion', value: widget.note.duration),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Transcripcion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _showTranscript = !_showTranscript),
                    child: Text(_showTranscript ? 'Ocultar' : 'Ver')),
                ]),
                if (_showTranscript) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(widget.note.transcript.isEmpty ? '(sin transcripcion)' : widget.note.transcript,
                      style: const TextStyle(fontSize: 13, height: 1.6)),
                  ),
                ],
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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 22),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      ]),
    );
  }
}
