import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/note.dart';
import '../services/api_service.dart';

class NoteScreen extends StatefulWidget {
  final Map<String, dynamic>? noteData;
  final Note? note;

  const NoteScreen({super.key, this.noteData, this.note});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  late String _noteId;
  late String _subjectName;
  late String _transcript;
  late String _structuredNotes;
  late int _durationSeconds;
  late String _createdAt;

  // FIX v7: modo edición
  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _editController;
  String? _editError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.noteData != null) {
      final d = widget.noteData!;
      _noteId = d['id'] ?? '';
      _subjectName = d['subject_name'] ?? '';
      _transcript = d['transcript'] ?? '';
      _structuredNotes = d['structured_notes'] ?? '';
      _durationSeconds = d['duration_seconds'] ?? 0;
      _createdAt = d['created_at'] ?? '';
    } else if (widget.note != null) {
      final n = widget.note!;
      _noteId = n.id;
      _subjectName = n.subjectName;
      _transcript = n.transcript;
      _structuredNotes = n.structuredNotes;
      _durationSeconds = n.durationSeconds;
      _createdAt = n.createdAt;
    } else {
      _noteId = '';
      _subjectName = '';
      _transcript = '';
      _structuredNotes = '';
      _durationSeconds = 0;
      _createdAt = '';
    }

    _editController = TextEditingController(text: _structuredNotes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  // ─── FIX v7: Guardar edición ──────────────────────────────────────────────

  Future<void> _saveEdit() async {
    if (_noteId.isEmpty) {
      _showSnack('Esta nota aún no está guardada en el servidor.');
      return;
    }
    setState(() {
      _isSaving = true;
      _editError = null;
    });
    try {
      await _api.updateNote(_noteId, _editController.text.trim());
      setState(() {
        _structuredNotes = _editController.text.trim();
        _isEditing = false;
        _isSaving = false;
      });
      _showSnack('Notas guardadas ✅');
    } catch (e) {
      setState(() {
        _editError = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  void _cancelEdit() {
    _editController.text = _structuredNotes;
    setState(() {
      _isEditing = false;
      _editError = null;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Compartir como PDF ───────────────────────────────────────────────────

  Future<void> _shareAsPdf() async {
    try {
      final pdfDoc = pw.Document();
      pdfDoc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(_subjectName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Duración: ${_formatDuration(_durationSeconds)}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          pw.Text('NOTAS ESTRUCTURADAS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(_structuredNotes),
          pw.SizedBox(height: 20),
          pw.Text('TRANSCRIPCIÓN',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(_transcript),
        ],
      ));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/classmind_nota.pdf');
      await file.writeAsBytes(await pdfDoc.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'Nota: $_subjectName');
    } catch (e) {
      _showSnack('Error generando PDF: $e');
    }
  }

  Future<void> _copyTranscript() async {
    await Clipboard.setData(ClipboardData(text: _transcript));
    _showSnack('Transcripción copiada al portapapeles');
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_subjectName.isEmpty ? 'Nota' : _subjectName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // FIX v7: botón editar / guardar
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar notas',
              onPressed: () {
                _tabController.animateTo(0); // Ir a pestaña Notas
                setState(() => _isEditing = true);
              },
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Compartir PDF',
            onPressed: _shareAsPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Notas', icon: Icon(Icons.notes)),
            Tab(text: 'Transcripción', icon: Icon(Icons.text_snippet)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info de duración
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Duración: ${_formatDuration(_durationSeconds)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                if (_createdAt.isNotEmpty)
                  Text(
                    _createdAt.length > 10 ? _createdAt.substring(0, 10) : _createdAt,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0: Notas estructuradas ──────────────────────────
                _buildNotesTab(),

                // ── Tab 1: Transcripción ────────────────────────────────
                _buildTranscriptTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_isEditing) {
      // FIX v7: modo edición
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('✏️ Editando notas',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton(onPressed: _isSaving ? null : _cancelEdit,
                        child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveEdit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
            if (_editError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_editError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _editController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Escribe las notas aquí (Markdown soportado)...',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Vista normal (Markdown)
    if (_structuredNotes.isEmpty) {
      return const Center(
          child: Text('No hay notas generadas',
              style: TextStyle(color: Colors.grey)));
    }
    return Markdown(
      data: _structuredNotes,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
        h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        p: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildTranscriptTab() {
    if (_transcript.isEmpty) {
      return const Center(
          child: Text('Sin transcripción', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar'),
                onPressed: _copyTranscript,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              _transcript,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
