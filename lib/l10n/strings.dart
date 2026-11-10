class S {
  static bool isEnglish = false;

  // General
  static String get appSubtitle    => isEnglish ? 'Your classes, intelligent' : 'Tus clases, inteligentes';
  static String get loading        => isEnglish ? 'Loading...' : 'Cargando...';
  static String get cancel         => isEnglish ? 'Cancel' : 'Cancelar';
  static String get delete         => isEnglish ? 'Delete' : 'Eliminar';
  static String get save           => isEnglish ? 'Save' : 'Guardar';
  static String get create         => isEnglish ? 'Create' : 'Crear';
  static String get error          => isEnglish ? 'Error' : 'Error';
  static String get languageLabel  => isEnglish ? 'Language / Idioma' : 'Idioma / Language';
  static String get langEs         => 'Español';
  static String get langEn         => 'English';

  // Login
  static String get signIn         => isEnglish ? 'Sign In' : 'Iniciar sesion';
  static String get email          => isEnglish ? 'Email' : 'Correo electronico';
  static String get password       => isEnglish ? 'Password' : 'Contrasena';
  static String get enterBtn       => isEnglish ? 'Enter' : 'Entrar';
  static String get noAccount      => isEnglish ? "Don't have an account? " : 'No tienes cuenta? ';
  static String get registerLink   => isEnglish ? 'Sign up' : 'Registrate';
  static String get configServer   => isEnglish ? 'Configure server' : 'Configurar servidor';

  // Register
  static String get createAccount  => isEnglish ? 'Create account' : 'Crear cuenta';
  static String get fullName       => isEnglish ? 'Full name' : 'Nombre completo';
  static String get passwordHint   => isEnglish ? 'Password (min. 6 chars)' : 'Contrasena (min. 6 caracteres)';
  static String get fillAllFields  => isEnglish ? 'Fill in all fields' : 'Completa todos los campos';
  static String get accountCreated => isEnglish ? 'Account created! Sign in.' : 'Cuenta creada! Inicia sesion';

  // Home
  static String get hello          => isEnglish ? 'Hello, ' : 'Hola, ';
  static String get yourSubjects   => isEnglish ? 'Your subjects' : 'Tus materias';
  static String get noSubjects     => isEnglish ? 'No subjects yet' : 'No tienes materias aun';
  static String get tapToAdd       => isEnglish ? 'Tap + to add one' : 'Toca + para agregar una';
  static String get newSubject     => isEnglish ? 'New subject' : 'Nueva materia';
  static String get subjectName    => isEnglish ? 'Subject name' : 'Nombre de la materia';
  static String get subjectHint    => isEnglish ? 'e.g. Calculus III' : 'Ej: Calculo III';
  static String get professor      => isEnglish ? 'Professor (optional)' : 'Profesor (opcional)';
  static String get professorHint  => isEnglish ? 'e.g. Dr. Garcia' : 'Ej: Dr. Garcia';
  static String get deleteSubject  => isEnglish ? 'Delete subject' : 'Eliminar materia';
  static String get deleteSubjectQ => isEnglish ? 'Delete "{name}" and all its notes?' : 'Eliminar "{name}" y todas sus notas?';
  static String get serverError    => isEnglish ? 'Could not connect to server.\nCheck IP in Settings.' : 'No se pudo conectar al servidor.\nVerifica la IP en Configuracion.';
  static String get errorCreating  => isEnglish ? 'Error creating subject' : 'Error al crear materia';

  // Subject screen
  static String get classNotes     => isEnglish ? 'Class notes' : 'Notas de clase';
  static String get noNotes        => isEnglish ? 'No notes for this subject' : 'No hay notas para esta materia';
  static String get uploadFirst    => isEnglish ? 'Upload an audio to get started' : 'Sube un audio para comenzar';
  static String get deleteNote     => isEnglish ? 'Delete note' : 'Eliminar nota';
  static String get deleteNoteQ    => isEnglish ? 'Delete this note?' : 'Eliminar esta nota?';
  static String get qaBtn          => isEnglish ? 'Q&A' : 'Q&A';
  static String get prof           => isEnglish ? 'Prof. ' : 'Prof. ';

  // Upload screen
  static String get uploadAudio    => isEnglish ? 'Upload Audio' : 'Subir Audio';
  static String get selectFile     => isEnglish ? 'Select audio file' : 'Seleccionar archivo de audio';
  static String get noFileSelected => isEnglish ? 'No file selected' : 'Ningun archivo seleccionado';
  static String get process        => isEnglish ? 'Process' : 'Procesar';
  static String get processing     => isEnglish ? 'Processing... this may take a few minutes' : 'Procesando... puede tardar unos minutos';

  // Note screen
  static String get notes          => isEnglish ? 'Notes' : 'Notas';
  static String get info           => isEnglish ? 'Info' : 'Info';
  static String get subject        => isEnglish ? 'Subject' : 'Materia';
  static String get date           => isEnglish ? 'Date' : 'Fecha';
  static String get duration       => isEnglish ? 'Duration' : 'Duracion';
  static String get transcript     => isEnglish ? 'Transcript' : 'Transcripcion';
  static String get show           => isEnglish ? 'Show' : 'Ver';
  static String get hide           => isEnglish ? 'Hide' : 'Ocultar';
  static String get noTranscript   => isEnglish ? '(no transcript)' : '(sin transcripcion)';
  static String get exportPdf      => isEnglish ? 'Export PDF' : 'Exportar PDF';
  static String get exportTxt      => isEnglish ? 'Export TXT' : 'Exportar TXT';

  // Settings
  static String get settings       => isEnglish ? 'Settings' : 'Configuracion';
  static String get serverUrl      => isEnglish ? 'Server URL' : 'URL del servidor';
  static String get saveUrl        => isEnglish ? 'Save URL' : 'Guardar URL';
  static String get urlSaved       => isEnglish ? 'URL saved' : 'URL guardada';
  static String get account        => isEnglish ? 'Account' : 'Cuenta';
  static String get signOut        => isEnglish ? 'Sign out' : 'Cerrar sesion';

  // QA
  static String get qaTitle        => isEnglish ? 'Q&A — ' : 'Q&A — ';
  static String get askPlaceholder => isEnglish ? 'Ask about this subject...' : 'Pregunta sobre esta materia...';
  static String get askBtn         => isEnglish ? 'Ask' : 'Preguntar';

  // Months
  static String month(int m) {
    const es = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const en = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                 'July', 'August', 'September', 'October', 'November', 'December'];
    return isEnglish ? en[m] : es[m];
  }
}
