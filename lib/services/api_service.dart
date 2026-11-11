import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class ApiService {
  static const String baseUrl =
      'https://classmind-backend-umtc.onrender.com/api/v1';

  // ─── Claves en SharedPreferences ──────────────────────────────────────────
  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';   // FIX v7
  static const _keyUserId = 'user_id';
  static const _keyEmail = 'user_email';
  static const _keyName = 'user_name';

  // ─── Almacenamiento de sesión ──────────────────────────────────────────────

  Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String userId,
    required String email,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRefreshToken, refreshToken);  // FIX v7
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyName, name);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyName);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) != null;
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  // ─── FIX v7: Obtener token válido (refresca si expiró) ────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;

    // Verificar si el JWT ha expirado o expirará en los próximos 5 minutos
    if (_isTokenExpiredOrExpiringSoon(token)) {
      final refreshToken = prefs.getString(_keyRefreshToken);
      if (refreshToken == null) return null;
      try {
        final newSession = await _refreshToken(refreshToken);
        await prefs.setString(_keyToken, newSession['token']!);
        await prefs.setString(_keyRefreshToken, newSession['refresh_token']!);
        return newSession['token'];
      } catch (e) {
        // No se pudo refrescar — forzar re-login
        await clearSession();
        return null;
      }
    }

    return token;
  }

  /// Decodifica el JWT y verifica si expira en < 5 minutos.
  bool _isTokenExpiredOrExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = json.decode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
    } catch (_) {
      return true;
    }
  }

  /// Llama al endpoint /auth/refresh del backend.
  Future<Map<String, String>> _refreshToken(String refreshToken) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'token': data['token'] as String,
        'refresh_token': data['refresh_token'] as String,
      };
    }
    throw Exception('No se pudo refrescar el token: ${response.statusCode}');
  }

  // ─── Cabecera de autorización ──────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    if (token == null) throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─── AUTH ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await saveSession(
        token: data['token'],
        refreshToken: data['refresh_token'] ?? '',
        userId: data['user_id'],
        email: email,
        name: data['name'] ?? '',
      );
      return data;
    }
    throw Exception('Credenciales inválidas');
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'password': password, 'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await saveSession(
        token: data['token'],
        refreshToken: data['refresh_token'] ?? '',
        userId: data['user_id'],
        email: email,
        name: name,
      );
      return data;
    }
    final body = json.decode(response.body);
    throw Exception(body['detail'] ?? 'Error al registrar');
  }

  // ─── SUBJECTS ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getSubjects() async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/subjects'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['subjects'] as List;
    }
    throw Exception('Error obteniendo materias: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createSubject(
      String name, String? professorName) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/subjects'),
          headers: headers,
          body: json.encode({
            'name': name,
            if (professorName != null && professorName.isNotEmpty)
              'professor_name': professorName,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error creando materia');
  }

  Future<void> deleteSubject(String subjectId) async {
    final headers = await _authHeaders();
    final response = await http
        .delete(Uri.parse('$baseUrl/subjects/$subjectId'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Error eliminando materia');
    }
  }

  Future<void> uploadPdf(String subjectId, File pdfFile) async {
    final token = await _getToken();
    if (token == null) throw Exception('Sesión expirada');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/subjects/$subjectId/pdf'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('pdf_file', pdfFile.path));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    if (streamed.statusCode != 200) {
      throw Exception('Error subiendo PDF: ${streamed.statusCode}');
    }
  }

  Future<void> deletePdf(String subjectId) async {
    final headers = await _authHeaders();
    await http
        .delete(Uri.parse('$baseUrl/subjects/$subjectId/pdf'), headers: headers)
        .timeout(const Duration(seconds: 15));
  }

  // ─── AUDIO ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> processAudio({
    required File audioFile,
    required String subjectId,
    void Function(String status)? onStatus,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Sesión expirada. Vuelve a iniciar sesión.');

    onStatus?.call('Subiendo audio...');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/process-audio'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['subject_id'] = subjectId
      ..files.add(await http.MultipartFile.fromPath(
        'audio_file',
        audioFile.path,
        // FIX v7: pasar filename con extensión para que el backend lo detecte
        filename: audioFile.path.split('/').last,
      ));

    onStatus?.call('Transcribiendo con Whisper...');

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 20),
      onTimeout: () => throw Exception(
          'Tiempo de espera agotado. El audio puede ser muy largo.'),
    );

    onStatus?.call('Generando notas con IA...');

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await clearSession();
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }

    final body = json.decode(response.body);
    throw Exception(body['detail'] ?? 'Error procesando audio (${response.statusCode})');
  }

  // ─── NOTES ────────────────────────────────────────────────────────────────

  Future<List<Note>> getNotes() async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/notes'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['notes'] as List)
          .map((n) => Note.fromJson(n as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error obteniendo notas');
  }

  Future<Note> getNote(String noteId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/notes/$noteId'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return Note.fromJson(json.decode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Nota no encontrada');
  }

  Future<void> deleteNote(String noteId) async {
    final headers = await _authHeaders();
    final response = await http
        .delete(Uri.parse('$baseUrl/notes/$noteId'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Error eliminando nota');
    }
  }

  // FIX v7: Actualizar notas estructuradas (edición)
  Future<void> updateNote(String noteId, String structuredNotes) async {
    final headers = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/notes/$noteId'),
          headers: headers,
          body: json.encode({'structured_notes': structuredNotes}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Error guardando cambios: ${response.statusCode}');
    }
  }

  // ─── Q&A ──────────────────────────────────────────────────────────────────

  // FIX v7: eliminado user_id del body (backend lo obtiene del token)
  Future<String> askQuestion(String question, String subjectId) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/qa'),
          headers: headers,
          body: json.encode({
            'question': question,
            'subject_id': subjectId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['answer'] as String;
    }
    throw Exception('Error en Q&A: ${response.statusCode}');
  }
}
