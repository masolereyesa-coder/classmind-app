import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../l10n/strings.dart';

class SubjectScreen extends StatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});
  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notes = await ApiService.getNotes(subjectId: widget.subject.id);
      setState(() => _notes = notes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.error)));
    } finally { setState(() => _loading = false); }
  }

  Future<void> _deleteNote(Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.deleteNote),
        content: Text(S.deleteNoteQ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: Text(S.delete)),
        ],
      ),
    );
    if (ok == true) { await ApiService.deleteNote(n.id); _load(); }
  }

  String _formatDate(String iso) {
    try { final d = DateTime.parse(iso); return '${d.day} ${S.month(d.month)} ${d.year}'; }
    catch (_) { return iso.split('T').first; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.question_answer_outlined),
            tooltip: S.qaBtn,
            onPressed: () => Navigator.pushNamed(context, '/qa', arguments: widget.subject),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.subject.professorName.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: const Color(0xFF6C63FF),
                    child: Row(children: [
                      const Icon(Icons.person, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text('${S.prof}${widget.subject.professorName}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      Text('${_notes.length} ${S.notes.toLowerCase()}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                Expanded(
                  child: _notes.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.note_add_outlined, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(S.noNotes, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(S.uploadFirst, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/upload', arguments: widget.subject).then((_) => _load()),
                            icon: const Icon(Icons.mic),
                            label: Text(S.uploadAudio),
                          ),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _notes.length,
                            itemBuilder: (ctx, i) {
                              final n = _notes[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.description_outlined, color: Color(0xFF6C63FF)),
                                  ),
                                  title: Text('${S.classNotes}: ${_formatDate(n.createdAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Row(children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(n.duration, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ]),
                                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteNote(n)),
                                  onTap: () => Navigator.pushNamed(context, '/note', arguments: n),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/upload', arguments: widget.subject).then((_) => _load()),
        icon: const Icon(Icons.mic),
        label: Text(S.uploadAudio),
      ),
    );
  }
}
