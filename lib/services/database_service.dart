import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'medical_app.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _patientsTable = 'patients';
  static const String _conversationsTable = 'conversations';
  static const String _transcriptionsTable = 'transcriptions';
  static const String _llmOutputsTable = 'llm_outputs';

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
    );
  }

  // Create database tables
  static Future<void> _createDatabase(Database db, int version) async {
    // Patients table
    await db.execute('''
      CREATE TABLE $_patientsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dob TEXT NOT NULL,
        gender TEXT NOT NULL,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Conversations table
    await db.execute('''
      CREATE TABLE $_conversationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        title TEXT,
        duration INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES $_patientsTable (id) ON DELETE CASCADE
      )
    ''');

    // Transcriptions table
    await db.execute('''
      CREATE TABLE $_transcriptionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        transcript TEXT NOT NULL,
        duration INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES $_conversationsTable (id) ON DELETE CASCADE
      )
    ''');

    // LLM Outputs table
    await db.execute('''
      CREATE TABLE $_llmOutputsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        raw_output TEXT NOT NULL,
        parsed_json TEXT,
        extraction_success INTEGER NOT NULL DEFAULT 0,
        duration INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES $_conversationsTable (id) ON DELETE CASCADE
      )
    ''');
  }

  // Patient operations
  static Future<int> insertPatient(PatientData patient) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.insert(_patientsTable, {
      'name': patient.name,
      'dob': patient.dob,
      'gender': patient.gender,
      'address': patient.address,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<PatientData?> getPatient(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _patientsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return PatientData.fromMap(maps.first);
    }
    return null;
  }

  static Future<List<PatientData>> getAllPatients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _patientsTable,
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => PatientData.fromMap(maps[i]));
  }

  static Future<int> updatePatient(PatientData patient) async {
    final db = await database;
    return await db.update(
      _patientsTable,
      {
        'name': patient.name,
        'dob': patient.dob,
        'gender': patient.gender,
        'address': patient.address,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  static Future<int> deletePatient(int id) async {
    final db = await database;
    return await db.delete(
      _patientsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Conversation operations
  static Future<int> insertConversation(ConversationData conversation) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.insert(_conversationsTable, {
      'patient_id': conversation.patientId,
      'title': conversation.title,
      'duration': conversation.duration,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<ConversationData?> getConversation(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _conversationsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ConversationData.fromMap(maps.first);
    }
    return null;
  }

  static Future<List<ConversationData>> getConversationsByPatient(int patientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _conversationsTable,
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => ConversationData.fromMap(maps[i]));
  }

  static Future<List<ConversationData>> getAllConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _conversationsTable,
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => ConversationData.fromMap(maps[i]));
  }

  static Future<int> updateConversation(ConversationData conversation) async {
    final db = await database;
    return await db.update(
      _conversationsTable,
      {
        'title': conversation.title,
        'duration': conversation.duration,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  static Future<int> deleteConversation(int id) async {
    final db = await database;
    return await db.delete(
      _conversationsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transcription operations
  static Future<int> insertTranscription(TranscriptionData transcription) async {
    final db = await database;
    
    return await db.insert(_transcriptionsTable, {
      'conversation_id': transcription.conversationId,
      'transcript': transcription.transcript,
      'duration': transcription.duration,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<TranscriptionData?> getTranscriptionByConversation(int conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _transcriptionsTable,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    if (maps.isNotEmpty) {
      return TranscriptionData.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> updateTranscription(TranscriptionData transcription) async {
    final db = await database;
    return await db.update(
      _transcriptionsTable,
      {
        'transcript': transcription.transcript,
        'duration': transcription.duration,
      },
      where: 'id = ?',
      whereArgs: [transcription.id],
    );
  }

  // LLM Output operations
  static Future<int> insertLlmOutput(LlmOutputData llmOutput) async {
    final db = await database;
    
    return await db.insert(_llmOutputsTable, {
      'conversation_id': llmOutput.conversationId,
      'raw_output': llmOutput.rawOutput,
      'parsed_json': llmOutput.parsedJson != null ? jsonEncode(llmOutput.parsedJson) : null,
      'extraction_success': llmOutput.extractionSuccess ? 1 : 0,
      'duration': llmOutput.duration,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<LlmOutputData?> getLlmOutputByConversation(int conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _llmOutputsTable,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    if (maps.isNotEmpty) {
      return LlmOutputData.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> updateLlmOutput(LlmOutputData llmOutput) async {
    final db = await database;
    return await db.update(
      _llmOutputsTable,
      {
        'raw_output': llmOutput.rawOutput,
        'parsed_json': llmOutput.parsedJson != null ? jsonEncode(llmOutput.parsedJson) : null,
        'extraction_success': llmOutput.extractionSuccess ? 1 : 0,
        'duration': llmOutput.duration,
      },
      where: 'id = ?',
      whereArgs: [llmOutput.id],
    );
  }

  // Complete conversation data with all related information
  static Future<CompleteConversationData?> getCompleteConversation(int conversationId) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) return null;

    final patient = await getPatient(conversation.patientId);
    final transcription = await getTranscriptionByConversation(conversationId);
    final llmOutput = await getLlmOutputByConversation(conversationId);

    return CompleteConversationData(
      conversation: conversation,
      patient: patient,
      transcription: transcription,
      llmOutput: llmOutput,
    );
  }

  // Get conversation history for a patient
  static Future<List<CompleteConversationData>> getPatientConversationHistory(int patientId) async {
    final conversations = await getConversationsByPatient(patientId);
    final List<CompleteConversationData> completeConversations = [];

    for (final conversation in conversations) {
      final complete = await getCompleteConversation(conversation.id!);
      if (complete != null) {
        completeConversations.add(complete);
      }
    }

    return completeConversations;
  }

  // Search functionality
  static Future<List<PatientData>> searchPatients(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _patientsTable,
      where: 'name LIKE ? OR address LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => PatientData.fromMap(maps[i]));
  }

  // Database maintenance
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(_llmOutputsTable);
    await db.delete(_transcriptionsTable);
    await db.delete(_conversationsTable);
    await db.delete(_patientsTable);
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

// Data models
class PatientData {
  final int? id;
  final String name;
  final String dob;
  final String gender;
  final String? address;
  final String? createdAt;
  final String? updatedAt;

  PatientData({
    this.id,
    required this.name,
    required this.dob,
    required this.gender,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': dob,
      'gender': gender,
      'address': address,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PatientData.fromMap(Map<String, dynamic> map) {
    return PatientData(
      id: map['id'],
      name: map['name'],
      dob: map['dob'],
      gender: map['gender'],
      address: map['address'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  // Convert to/from the existing patient format used in the app
  Map<String, dynamic> toPatientFormat() {
    return {
      'name': name,
      'dob': dob,
      'gender': gender,
      'address': address ?? '',
    };
  }

  factory PatientData.fromPatientFormat(Map<String, dynamic> patient) {
    return PatientData(
      name: patient['name'],
      dob: patient['dob'],
      gender: patient['gender'],
      address: patient['address'],
    );
  }
}

class ConversationData {
  final int? id;
  final int patientId;
  final String? title;
  final int? duration; // in seconds
  final String? createdAt;
  final String? updatedAt;

  ConversationData({
    this.id,
    required this.patientId,
    this.title,
    this.duration,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'title': title,
      'duration': duration,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ConversationData.fromMap(Map<String, dynamic> map) {
    return ConversationData(
      id: map['id'],
      patientId: map['patient_id'],
      title: map['title'],
      duration: map['duration'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class TranscriptionData {
  final int? id;
  final int conversationId;
  final String transcript;
  final int? duration; // in seconds
  final String? createdAt;

  TranscriptionData({
    this.id,
    required this.conversationId,
    required this.transcript,
    this.duration,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'transcript': transcript,
      'duration': duration,
      'created_at': createdAt,
    };
  }

  factory TranscriptionData.fromMap(Map<String, dynamic> map) {
    return TranscriptionData(
      id: map['id'],
      conversationId: map['conversation_id'],
      transcript: map['transcript'],
      duration: map['duration'],
      createdAt: map['created_at'],
    );
  }
}

class LlmOutputData {
  final int? id;
  final int conversationId;
  final String rawOutput;
  final Map<String, dynamic>? parsedJson;
  final bool extractionSuccess;
  final int? duration; // in seconds
  final String? createdAt;

  LlmOutputData({
    this.id,
    required this.conversationId,
    required this.rawOutput,
    this.parsedJson,
    required this.extractionSuccess,
    this.duration,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'raw_output': rawOutput,
      'parsed_json': parsedJson != null ? jsonEncode(parsedJson) : null,
      'extraction_success': extractionSuccess ? 1 : 0,
      'duration': duration,
      'created_at': createdAt,
    };
  }

  factory LlmOutputData.fromMap(Map<String, dynamic> map) {
    return LlmOutputData(
      id: map['id'],
      conversationId: map['conversation_id'],
      rawOutput: map['raw_output'],
      parsedJson: map['parsed_json'] != null ? jsonDecode(map['parsed_json']) : null,
      extractionSuccess: map['extraction_success'] == 1,
      duration: map['duration'],
      createdAt: map['created_at'],
    );
  }
}

class CompleteConversationData {
  final ConversationData conversation;
  final PatientData? patient;
  final TranscriptionData? transcription;
  final LlmOutputData? llmOutput;

  CompleteConversationData({
    required this.conversation,
    this.patient,
    this.transcription,
    this.llmOutput,
  });
}
