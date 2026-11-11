import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import 'note_screen.dart';

// Estados del proceso
enum _Step { idle, uploading, transcribing, generating, done, error }

class UploadScreen extends StatefulWidget {
  final Subject subject;
  const UploadScreen({super.key, required this.subject});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _mode = 0; // 0 = upload, 1 = record

  // Upload
  String? _filePath;
  String? _fileName;

  // Record
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  String? _recordedPath;

  // FIX v7: reproductor de audio
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _playPos = Duration.zero;
  Duration _playDur = Duration.zero;

  // FIX v7: progreso multi-etapa
  _Step _step = _Step.idle;
  String _statusMsg = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((p) { if (mounted) setState(() => _playPos = p); });
    _player.durationStream.listen((d) { if (mounted && d != null) setState(() => _playDur = d); });
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Grabación ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('Se necesita permiso de micrófono');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/classmind_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _recordedPath = null;
      _filePath = null;
      _fileName = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording && mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
    if (path != null) _loadPlayer(path);
  }

  // ── Archivo externo ───────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'm4a', 'wav', 'ogg', 'flac', 'webm', 'aac'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        _recordedPath = null;
        _isRecording = false;
      });
      _loadPlayer(_filePath!);
    }
  }

  // ── FIX v7: Reproductor ───────────────────────────────────────────────────

  Future<void> _loadPlayer(String path) async {
    try { await _player.setFilePath(path); } catch (_) {}
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
      await _player.play();
    }
  }

  Widget _buildPlayer() {
    final hasAudio = _recordedPath != null || _filePath != null;
    if (!hasAudio) return const SizedBox.shrink();
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 32, color: Colors.indigo),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Slider(
              value: _playPos.inSeconds.toDouble().clamp(0, _playDur.inSeconds > 0 ? _playDur.inSeconds.toDouble() : 1),
              min: 0,
              max: _playDur.inSeconds > 0 ? _playDur.inSeconds.toDouble() : 1,
              onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
              activeColor: Colors.indigo,
            ),
          ),
          Text('${_fmt(_playPos)} / ${_fmt(_playDur)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }

  // ── FIX v7: Indicador de progreso ─────────────────────────────────────────

  Widget _buildProgress() {
    final steps = [
      (_Step.uploading, Icons.upload, 'Subiendo audio'),
      (_Step.transcribing, Icons.mic_none, 'Transcribiendo con Whisper'),
      (_Step.generating, Icons.auto_awesome, 'Generando notas con IA'),
    ];
    final stepOrder = [_Step.uploading, _Step.transcribing, _Step.generating];
    final curIdx = stepOrder.indexOf(_step);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      const LinearProgressIndicator(),
      const SizedBox(height: 16),
      ...steps.map((e) {
        final (s, icon, label) = e;
        final idx = stepOrder.indexOf(s);
        final done = curIdx > idx;
        final active = curIdx == idx;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(done ? Icons.check_circle : (active ? icon : Icons.circle_outlined),
                color: done ? Colors.green : (active ? Colors.indigo : Colors.grey.shade400)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.green.shade700 : (active ? Colors.indigo : Colors.grey),
                )),
            if (active) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
        );
      }),
    ]);
  }

  // ── Enviar al backend ──────────────────────────────────────────────────────

  Future<void> _process() async {
    final path = _mode == 0 ? _filePath : _recordedPath;
    if (path == null) {
      _showSnack(_mode == 0 ? 'Selecciona un archivo primero' : 'Graba audio primero');
      return;
    }
    setState(() { _step = _Step.uploading; _statusMsg = ''; _error = null; });

    try {
      final note = await ApiService.processAudio(
        path,
        widget.subject.id,
        onStatus: (msg) {
          if (!mounted) return;
          setState(() {
            _statusMsg = msg;
            if (msg.contains('Subiendo')) _step = _Step.uploading;
            else if (msg.contains('Transcrib')) _step = _Step.transcribing;
            else if (msg.contains('Generando') || msg.contains('IA')) _step = _Step.generating;
          });
        },
      );
      setState(() => _step = _Step.done);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NoteScreen(note: note)));
    } catch (e) {
      setState(() {
        _step = _Step.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── UI ────────────────────────────────────────────────────────────────────

  bool get _isProcessing =>
      _step != _Step.idle && _step != _Step.done && _step != _Step.error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva nota — ${widget.subject.name}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Selector de modo ─────────────────────────────────────────
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Subir archivo'), icon: Icon(Icons.folder_open)),
              ButtonSegment(value: 1, label: Text('Grabar'), icon: Icon(Icons.mic)),
            ],
            selected: {_mode},
            onSelectionChanged: _isProcessing ? null : (s) => setState(() { _mode = s.first; }),
          ),
          const SizedBox(height: 20),

          // ── Modo: Subir archivo ───────────────────────────────────────
          if (_mode == 0) ...[
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Seleccionar archivo de audio'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(height: 4),
            const Text('Formatos: mp3, m4a, wav, ogg, flac, aac, webm, mp4',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(_fileName!, style: const TextStyle(color: Colors.green),
                    overflow: TextOverflow.ellipsis)),
              ]),
              _buildPlayer(),
            ],
          ],

          // ── Modo: Grabar ──────────────────────────────────────────────
          if (_mode == 1) ...[
            if (_isRecording)
              Center(child: Text('⏱ Grabando: ${_fmt(_recordDuration)}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
            if (_recordedPath != null && !_isRecording)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 6),
                Text('Grabado: ${_fmt(_recordDuration)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : (_isRecording ? _stopRecording : _startRecording),
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Detener grabación' : 'Iniciar grabación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
            if (_recordedPath != null && !_isRecording) _buildPlayer(),
          ],

          const SizedBox(height: 24),

          // ── FIX v7: Progreso ──────────────────────────────────────────
          if (_isProcessing) _buildProgress(),

          // ── Error ─────────────────────────────────────────────────────
          if (_step == _Step.error && _error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // ── Botón principal ───────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _process,
            icon: _isProcessing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_isProcessing ? 'Procesando...' : 'Generar notas con IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          const Text('El procesamiento puede tardar 1–5 minutos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}
