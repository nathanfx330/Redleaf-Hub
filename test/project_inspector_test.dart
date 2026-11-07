import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:redleaf_hub/state/project_inspector.dart';

void main() {
  late Directory workspace;
  late Directory project;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('redleaf_hub_test_');
    project = Directory(p.join(workspace.path, 'sample_project'));
    await project.create(recursive: true);
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  test('notes round-trip and survive an independent read', () async {
    expect(await ProjectInspector.readNotes(project.path), isEmpty);

    const note = 'Research questions\nNext step: review transcripts';
    await ProjectInspector.saveNotes(project.path, note);

    expect(await ProjectInspector.readNotes(project.path), note);
    expect(
      await File(p.join(project.path, ProjectInspector.notesFileName)).exists(),
      isTrue,
    );
  });

  test('RLinks identify available and missing external folders', () async {
    final docs = Directory(p.join(project.path, 'documents'));
    await docs.create();
    final available = Directory(p.join(workspace.path, 'external'));
    await available.create();

    await File(p.join(docs.path, 'working.rlink'))
        .writeAsString(available.path);
    await File(p.join(docs.path, 'missing.rlink'))
        .writeAsString(p.join(workspace.path, 'not-mounted'));

    final links = await ProjectInspector.readLinks(project.path);
    expect(links, hasLength(2));
    expect(links.first.alias, 'missing.rlink');
    expect(links.first.isAvailable, isFalse);
    expect(links.last.alias, 'working.rlink');
    expect(links.last.isAvailable, isTrue);
    expect(links.last.targetPath, available.path);
  });

  test('repair updates the selected .rlink target without changing alias', () async {
    final docs = Directory(p.join(project.path, 'documents'));
    await docs.create();
    final replacement = Directory(p.join(workspace.path, 'replacement'));
    await replacement.create();

    final aliasFile = File(p.join(docs.path, 'archive.rlink'));
    await aliasFile.writeAsString('/a/missing/location');
    final originalLink = (await ProjectInspector.readLinks(project.path)).single;

    await ProjectInspector.updateLink(originalLink, replacement.path);

    final repaired = (await ProjectInspector.readLinks(project.path)).single;
    expect(repaired.alias, 'archive.rlink');
    expect(repaired.isAvailable, isTrue);
    expect(repaired.targetPath, replacement.absolute.path);
  });

  test('metadata shows missing database without requiring Python', () async {
    final metadata = await ProjectInspector.load(project.path);
    expect(metadata.tags, isEmpty);
    expect(metadata.tagsMessage, contains('No knowledge_base.db'));
    expect(metadata.links, isEmpty);
    expect(metadata.missingLinks, 0);
  });
}
