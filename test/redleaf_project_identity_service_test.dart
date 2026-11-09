// test/redleaf_project_identity_service_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redleaf_hub/services/redleaf_project_identity_service.dart';

void main() {
  test('reads canonical Redleaf instance ID from SQLite without modifying it',
      () async {
    final dir = await Directory.systemTemp.createTemp('hub_identity_test_');
    addTearDown(() => dir.delete(recursive: true));

    final database = File('${dir.path}/knowledge_base.db');
    final result = await Process.run('python3', <String>[
      '-c',
      'import sqlite3,sys;'
          'c=sqlite3.connect(sys.argv[1]);'
          'c.execute("CREATE TABLE app_settings (key TEXT, value TEXT)");'
          'c.execute("INSERT INTO app_settings VALUES (?,?)",'
          '("instance_id","test-uuid-4711"));'
          'c.commit();c.close()',
      database.path,
    ]);
    expect(result.exitCode, 0);

    final before = await database.lastModified();
    final id = await RedleafProjectIdentityService().readInstanceId(dir.path);

    expect(id, 'test-uuid-4711');
    expect(await database.lastModified(), before);
  });

  test('missing project database cannot create a credential binding',
      () async {
    final dir = await Directory.systemTemp.createTemp('hub_no_db_');
    addTearDown(() => dir.delete(recursive: true));

    await expectLater(
      RedleafProjectIdentityService().readInstanceId(dir.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('knowledge_base.db'),
        ),
      ),
    );
  });
}
