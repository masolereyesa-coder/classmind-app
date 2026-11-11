import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/api_service.dart';
import 'note_screen.dart';

// Estados del procesamiento de audio
enum _ProcessStep { idle, recording, uploading, transcribing, generating, done, error }

class UploadScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const UploadScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _api = ApiService();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();  // FIX v7: reproductor

  // Estado de grabación
  bool _isRecording = false;
  String? _recordedPath;
  Duration _recordDuration = Duration.zero;
  late final Stream<Duration> _recordTimer;

  // Estado de archivo externo
  File? _pickedFile;
  String? _pickedFileName;

  // Estado de reproducción (FIX v7)
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  File? _audioToPlay;   // el archivo listo para reproducir

  // Estado de procesamiento
  _ProcessStep _step = _ProcessStep.idle;
  String _statusMsg = '';
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    // Escuchar posición y duración del reproductor
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _playPosition = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _playDuration = dur);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ─── Grabación ────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('Se necesita permiso de micrófono');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/classmind_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _pickedFile = null;
      _pickedFileName = null;
      _audioToPlay = null;
    });

    // Contador de duración
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (_isRecording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
      if (path != null) {
        _audioToPlay = File(path);
      }
    });
    if (path != null) {
      _loadPlayerAudio(File(path));
    }
  }

  // ─── Archivo externo ──────────────────────────────────────────────────────

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'm4a', 'wav', 'ogg', 'flac', 'webm', 'aac'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _pickedFile = file;
        _pickedFileName = result.files.single.name;
        _recordedPath = null;
        _isRecording = false;
        _audioToPlay = file;
      });
      _loadPlayerAudio(file);
    }
  }

  // ─── FIX v7: Reproductor ──────────────────────────────────────────────────

  Future<void> _loadPlayerAudio(File file) async {
    try {
      await _player.setFilePath(file.path);
    } catch (e) {
      // Si no se puede cargar, simplemente ignoramos la reproducción
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildAudioPlayer() {
    if (_audioToPlay == null) return const SizedBox.shrink();
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 36, color: Colors.indigo),
                  onPressed: _togglePlayback,
                ),
                Expanded(
                  child: Slider(
                    value: _playPosition.inSeconds
                        .toDouble()
                        .clamp(0, _playDuration.inSeconds.toDouble()),
                    min: 0,
                    max: _playDuration.inSeconds > 0
                        ? _playDuration.inSeconds.toDouble()
                        : 1,
                    onChanged: (val) {
                      _player.seek(Duration(seconds: val.toInt()));
                    },
                    activeColor: Colors.indigo,
                  ),
                ),
                Text(
                  '${_formatDuration(_playPosition)} / ${_formatDuration(_playDuration)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── FIX v7: Progreso multi-etapa ─────────────────────────────────────────

  Widget _buildProgressIndicator() {
    final steps = [
      (_ProcessStep.uploading, Icons.upload, 'Subiendo audio'),
      (_ProcessStep.transcribing, Icons.mic_none, 'Transcribiendo con Whisper'),
      (_ProcessStep.generating, Icons.auto_awesome, 'Generando notas con IA'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const LinearProgressIndicator(),
        const SizedBox(height: 20),
        ...steps.map((entry) {
          final (stepVal, icon, label) = entry;
          final stepIdx = steps.indexWhere((e) => e.$1 == stepVal);
          final curIdx = steps.indexWhere((e) => e.$1 == _step);
          final isDone = curIdx > stepIdx;
          final isActive = curIdx == stepIdx;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : (isActive ? icon : Icons.circle_outlined),
                  color: isDone
                      ? Colors.green
                      : (isActive ? Colors.indigo : Colors.grey.shade400),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isDone
                        ? Colors.green.shade700
                        : (isActive ? Colors.indigo : Colors.grey),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          _statusMsg,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ─── Envío al backend ─────────────────────────────────────────────────────

  Future<void> _process() async {
    final file = _pickedFile ?? (_recordedPath != null ? File(_recordedPath!) : null);
    if (file == null) {
      _showSnack('Selecciona o graba un audio primero');
      return;
    }

    setState(() {
      _step = _ProcessStep.uploading;
      _statusMsg = 'Preparando envío...';
      _errorMsg = '';
    });

    try {
      final result = await _api.processAudio(
        audioFile: file,
        subjectId: widget.subjectId,
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _statusMsg = status;
              if (status.contains('Subiendo')) {
                _step = _ProcessStep.uploading;
              } else if (status.contains('Transcrib')) {
                _step = _ProcessStep.transcribing;
              } else if (status.contains('Generando') || status.contains('IA')) {
                _step = _ProcessStep.generating;
              }
            });
          }
        },
      );

      setState(() => _step = _ProcessStep.done);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NoteScreen(noteData: result),
        ),
      );
    } catch (e) {
      setState(() {
        _step = _ProcessStep.error;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isProcessing = _step != _ProcessStep.idle &&
        _step != _ProcessStep.done &&
        _step != _ProcessStep.error;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva nota — ${widget.subjectName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sección: Grabar ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎙️ Grabar clase',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (_isRecording)
                      Text(
                        'Grabando: ${_formatDuration(_recordDuration)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    if (_recordedPath != null && !_isRecording)
                      Text(
                        '✅ Grabado: ${_formatDuration(_recordDuration)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : (_isRecording ? _stopRecording : _startRecording),
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording ? 'Detener' : 'Grabar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isRecording ? Colors.red : Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_isRecording) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                    // FIX v7: Reproductor de audio grabado
                    if (_recordedPath != null && !_isRecording)
                      _buildAudioPlayer(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Sección: Subir archivo ───────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📁 Subir archivo de audio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Formatos: mp3, m4a, wav, ogg, flac, aac, webm, mp4',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : _pickAudioFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Seleccionar archivo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_pickedFileName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '✅ $_pickedFileName',
                        style: const TextStyle(color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // FIX v7: Reproductor de archivo externo
                      _buildAudioPlayer(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Procesamiento ────────────────────────────────────────────
            if (isProcessing) _buildProgressIndicator(),

            if (_step == _ProcessStep.error) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Botón procesar ───────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: isProcessing ? null : _process,
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(isProcessing ? 'Procesando...' : 'Generar notas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              'El procesamiento puede tardar 1–5 minutos dependiendo de la duración del audio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
