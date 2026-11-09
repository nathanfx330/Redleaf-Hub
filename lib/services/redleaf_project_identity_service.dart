// lib/services/redleaf_project_identity_service.dart

import 'dart:async';
import 'dart:io';

/// Get a Redleaf project's canonical database identity without opening Flask
/// or modifying knowledge_base.db. This is the credential vault lookup key.
class RedleafProjectIdentityService {
  static const String _readScript = r'''
import sqlite3
import sys
from pathlib import Path

database = Path(sys.argv[1]).resolve()
try:
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        row = connection.execute(
            "SELECT value FROM app_settings WHERE key = ?",
            ("instance_id",)
        ).fetchone()
        print(str(row[0]) if row and row[0] is not None else "")
    finally:
        connection.close()
except (sqlite3.Error, OSError):
    sys.exit(2)
''';

  Future<String> readInstanceId(String projectFolder) async {
    final folder = Directory(projectFolder).absolute;
    if (!await folder.exists()) {
      throw StateError('This Redleaf project folder does not exist.');
    }

    final db = File('${folder.path}/knowledge_base.db');
    if (!await db.exists()) {
      throw StateError(
        'This Redleaf project has no knowledge_base.db. '
        'Initialize it in Redleaf before saving login credentials.',
      );
    }

    try {
      final result = await Process.run(
        Platform.isWindows ? 'python' : 'python3',
        <String>['-c', _readScript, db.path],
      ).timeout(const Duration(seconds: 10));
      final id = result.stdout.toString().trim();
      if (result.exitCode != 0 || id.isEmpty ||
          id.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
        throw StateError(
          'Could not read a valid Redleaf database instance ID. '
          'Open this database in Redleaf once before saving credentials.',
        );
      }
      return id;
    } on TimeoutException {
      throw StateError('The local Redleaf database identity check timed out.');
    } on ProcessException {
      throw StateError('Python is required to identify this Redleaf project.');
    }
  }
}
