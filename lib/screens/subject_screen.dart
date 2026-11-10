import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import '../l10n/strings.dart';
import 'upload_screen.dart';
import 'note_screen.dart';

class SubjectScreen extends StatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  String? _error;

  // Track PDF filename locally so it updates after upload without full reload
  late String _pdfFilename;

  @override
  void initState() {
    super.initState();
    _pdfFilename = widget.subject.pdfFilename;
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes =
          await ApiService.getNotes(subjectId: widget.subject.id);
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _notes = notes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── PDF UPLOAD ─────────────────────────────────────────────────────────────

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    // Show uploading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(S.uploadingPdf),
          ],
        ),
        duration: const Duration(seconds: 60),
      ),
    );

    try {
      final data =
          await ApiService.uploadSubjectPdf(widget.subject.id, path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final filename = data['filename'] as String? ??
          result.files.first.name;
      setState(() => _pdfFilename = filename);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.pdfUploaded),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${S.pdfError}: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _deletePdf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.deletePdf),
        content: const Text('¿Eliminar el PDF de esta materia?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  Text(S.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteSubjectPdf(widget.subject.id);
      if (mounted) {
        setState(() => _pdfFilename = '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.pdfDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.error}: $e')),
        );
      }
    }
  }

  // ── PDF STATUS CHIP ────────────────────────────────────────────────────────

  Widget _buildPdfChip() {
    final hasPdf = _pdfFilename.isNotEmpty;
    return GestureDetector(
      onTap: hasPdf ? _showPdfOptions : _uploadPdf,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasPdf
              ? Colors.green.shade800.withOpacity(0.85)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPdf
                ? Colors.green.shade400
                : Colors.white.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPdf ? Icons.picture_as_pdf : Icons.upload_file_outlined,
              size: 16,
              color: hasPdf ? Colors.green.shade200 : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              hasPdf ? S.pdfLoaded : S.uploadPdf,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasPdf ? Colors.green.shade100 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.pdfLoaded,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _pdfFilename,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(S.changePdf),
              onTap: () {
                Navigator.pop(context);
                _uploadPdf();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
              title: Text(S.deletePdf,
                  style: TextStyle(color: Colors.red.shade600)),
              onTap: () {
                Navigator.pop(context);
                _deletePdf();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── NOTE CARD ──────────────────────────────────────────────────────────────

  Widget _buildNoteCard(Note note) {
    final date = DateTime.tryParse(note.createdAt);
    String dateStr = '';
    if (date != null) {
      dateStr =
          '${date.day} ${S.month(date.month)} ${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    final dur = note.durationSeconds;
    final durStr = dur != null
        ? '${(dur ~/ 60)}m ${(dur % 60).toString().padLeft(2, '0')}s'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteScreen(note: note)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (durStr.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        durStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              if (note.structuredNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _firstLine(note.structuredNotes),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _confirmDeleteNote(note),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(S.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstLine(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .trim();
    final lines = cleaned.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isNotEmpty ? lines.first : '';
  }

  Future<void> _confirmDeleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.deleteNote),
        content: Text(S.deleteNoteQ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  Text(S.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteNote(note.id);
      await _loadNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.subject.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subject.professorName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${S.prof}${widget.subject.professorName}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // PDF chip
                        _buildPdfChip(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Text(
                    S.classNotes,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadNotes,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _loadNotes,
                        child: const Text('Reintentar')),
                  ],
                ),
              ),
            )
          else if (_notes.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.note_add_outlined,
                        size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(S.noNotes,
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text(S.uploadFirst,
                        style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildNoteCard(_notes[i]),
                childCount: _notes.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  UploadScreen(subject: widget.subject),
            ),
          );
          _loadNotes();
        },
        icon: const Icon(Icons.mic),
        label: Text(S.uploadAudio),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
