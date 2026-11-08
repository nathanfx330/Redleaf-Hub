import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Read-only details obtained directly from a Redleaf project's local files.
class RedleafTag {
  const RedleafTag({required this.name, required this.documentCount});

  final String name;
  final int documentCount;
}

class RedleafLink {
  const RedleafLink({
    required this.alias,
    required this.filePath,
    required this.targetPath,
    required this.isAvailable,
    this.readError,
  });

  final String alias;
  final String filePath;
  final String targetPath;
  final bool isAvailable;
  final String? readError;
}

class ProjectMetadata {
  const ProjectMetadata({
    required this.tags,
    required this.links,
    this.tagsMessage,
  });

  final List<RedleafTag> tags;
  final List<RedleafLink> links;
  final String? tagsMessage;

  int get missingLinks => links.where((link) => !link.isAvailable).length;
}

/// Redleaf's tags are stored in knowledge_base.db. Its virtual folders are
/// plain-text documents/*.rlink files containing absolute directory paths.
///
/// Querying SQLite through Python's standard library avoids adding a native
/// SQLite dependency to the Flutter desktop build. Redleaf already requires
/// Python, and no Redleaf server, network access, or authentication is needed.
class ProjectInspector {
  static const notesFileName = '.redleaf_hub_notes.txt';

  static const _tagQueryScript = r'''
import json
import sqlite3
import sys
from pathlib import Path
from urllib.parse import quote

try:
    db_path = str(Path(sys.argv[1]).resolve()).replace('\\', '/')
    uri = 'file:' + quote(db_path, safe='/:') + '?mode=ro'
    connection = sqlite3.connect(uri, uri=True, timeout=3)
    try:
        rows = connection.execute(
            "SELECT t.name, COUNT(dt.doc_id) AS document_count "
            "FROM tags t LEFT JOIN document_tags dt ON dt.tag_id = t.id "
            "GROUP BY t.id, t.name ORDER BY t.name COLLATE NOCASE"
        ).fetchall()
        print(json.dumps({'tags': [
            {'name': name, 'documentCount': count} for name, count in rows
        ]}))
    finally:
        connection.close()
except Exception as exc:
    print(json.dumps({'error': str(exc)}))
''';

  static Future<ProjectMetadata> load(
    String projectPath, {
    String? condaEnv,
  }) async {
    final links = await readLinks(projectPath);
    final database = File(p.join(projectPath, 'knowledge_base.db'));
    if (!await database.exists()) {
      return ProjectMetadata(
        tags: const [],
        links: links,
        tagsMessage: 'No knowledge_base.db found. Run Redleaf to create the database.',
      );
    }

    final tags = await _readTags(database.path, condaEnv: condaEnv);
    return ProjectMetadata(
      tags: tags.tags,
      links: links,
      tagsMessage: tags.message,
    );
  }

  static Future<({List<RedleafTag> tags, String? message})> _readTags(
    String databasePath, {
    String? condaEnv,
  }) async {
    final commands = <List<String>>[
      [Platform.isWindows ? 'python' : 'python3'],
      if (!Platform.isWindows) ['python'],
      if (Platform.isWindows) ['py', '-3'],
      if (condaEnv != null && condaEnv.trim().isNotEmpty)
        ['conda', 'run', '-n', condaEnv.trim(), 'python'],
    ];

    for (final command in commands) {
      try {
        final result = await Process.run(
          command.first,
          [...command.skip(1), '-c', _tagQueryScript, databasePath],
        ).timeout(const Duration(seconds: 8));
        if (result.exitCode != 0) continue;

        final decoded = jsonDecode(result.stdout.toString());
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['error'] != null) {
          return (tags: <RedleafTag>[], message: decoded['error'].toString());
        }

        final rawTags = decoded['tags'];
        if (rawTags is! List) continue;
        final tags = rawTags.map((raw) {
          final row = raw as Map<String, dynamic>;
          return RedleafTag(
            name: row['name'] as String,
            documentCount: (row['documentCount'] as num).toInt(),
          );
        }).toList();
        return (tags: tags, message: null);
      } catch (_) {
        // Try the next installed Python interpreter / Conda environment.
      }
    }

    return (
      tags: <RedleafTag>[],
      message: 'Could not read tags. Python 3 is required (or configure a Conda environment in Settings).',
    );
  }

  static Future<List<RedleafLink>> readLinks(String projectPath) async {
    final documents = Directory(p.join(projectPath, 'documents'));
    if (!await documents.exists()) return [];

    final links = <RedleafLink>[];
    await for (final entity in documents.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.rlink') {
        continue;
      }

      var target = '';
      String? error;
      try {
        target = (await entity.readAsString()).trim();
      } catch (exception) {
        error = exception.toString();
      }

      final available =
          error == null &&
          target.isNotEmpty &&
          await Directory(target).exists();

      links.add(RedleafLink(
        alias: p.basename(entity.path),
        filePath: entity.path,
        targetPath: target,
        isAvailable: available,
        readError: error,
      ));
    }

    links.sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
    return links;
  }

  static Future<void> updateLink(RedleafLink link, String targetPath) async {
    final target = Directory(targetPath);
    if (!await target.exists()) {
      throw FileSystemException('Selected directory does not exist', targetPath);
    }
    await File(link.filePath).writeAsString(
      p.normalize(target.absolute.path),
      flush: true,
    );
  }

  static Future<String> readNotes(String projectPath) async {
    final file = File(p.join(projectPath, notesFileName));
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  static Future<void> saveNotes(String projectPath, String notes) async {
    await File(p.join(projectPath, notesFileName))
        .writeAsString(notes, flush: true);
  }
}
