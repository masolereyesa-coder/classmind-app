import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/subject.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Subject> _subjects = [];
  bool _loading = true;
  String? _userName;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _userName = await ApiService.getSavedUserName();
    try {
      final subs = await ApiService.getSubjects();
      setState(() => _subjects = subs);
    } catch (e) {
      _showError('No se pudo conectar al servidor.\nVerifica la IP en Configuracion.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _addSubject() {
    final nameCtrl = TextEditingController();
    final profCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva materia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre de la materia', hintText: 'Ej: Calculo III')),
            const SizedBox(height: 12),
            TextField(controller: profCtrl, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Profesor (opcional)', hintText: 'Ej: Dr. Garcia')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService.createSubject(nameCtrl.text.trim(), profCtrl.text.trim());
                _load();
              } catch (e) { _showError('Error al crear materia'); }
            },
            child: const Text('Crear')),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(Subject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar materia'),
        content: Text('Eliminar \"\${s.name}\" y todas sus notas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) { await ApiService.deleteSubject(s.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassMind'),
        actions: [
          IconButton(icon: const Icon(Icons.settings),
            onPressed: () async { await Navigator.pushNamed(context, '/settings'); _load(); }),
          IconButton(icon: const Icon(Icons.logout),
            onPressed: () async { await ApiService.logout(); if (!mounted) return; Navigator.pushReplacementNamed(context, '/login'); }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_userName != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: const BoxDecoration(color: Color(0xFF6C63FF)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hola, \$_userName', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Tus materias', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ]),
                  ),
                Expanded(
                  child: _subjects.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No tienes materias aun', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('Toca + para agregar una', style: TextStyle(color: Colors.grey)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _subjects.length,
                            itemBuilder: (ctx, i) {
                              final s = _subjects[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    radius: 24,
                                    child: Text(s.name[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: s.professorName.isNotEmpty ? Text('Prof. \${s.professorName}') : null,
                                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteSubject(s)),
                                  onTap: () => Navigator.pushNamed(context, '/subject', arguments: s).then((_) => _load()),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        icon: const Icon(Icons.add),
        label: const Text('Nueva materia'),
      ),
    );
  }
}
