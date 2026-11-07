import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:redleaf_hub/main.dart';
import 'package:redleaf_hub/state/hub_state.dart';

void main() {
  testWidgets('project library search filters folders and opens details',
      (WidgetTester tester) async {
    final workspace = await Directory.systemTemp.createTemp('redleaf_library_');
    addTearDown(() async {
      if (await workspace.exists()) await workspace.delete(recursive: true);
    });

    for (final name in ['First Archive', 'Second Dataset']) {
      final project = Directory(p.join(workspace.path, name));
      await project.create(recursive: true);
      await File(p.join(project.path, 'run.py')).writeAsString('');
    }

    SharedPreferences.setMockInitialValues({
      'homeDirectory': workspace.path,
      'nodeLeafPath': '/tmp/node_leaf',
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HubState(),
        child: const RedleafHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Project\nLibrary'));
    await tester.pumpAndSettle();

    expect(find.text('First Archive'), findsOneWidget);
    expect(find.text('Second Dataset'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'second');
    await tester.pumpAndSettle();

    expect(find.text('First Archive'), findsNothing);
    expect(find.text('Second Dataset'), findsOneWidget);

    await tester.tap(find.byTooltip('Project information').first);
    await tester.pumpAndSettle();

    expect(find.text('REDLEAF TAGS'), findsOneWidget);
    expect(find.text('RLINK LOCATIONS'), findsOneWidget);
    expect(find.text('PROJECT NOTES'), findsOneWidget);
  });
}
