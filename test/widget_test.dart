import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:redleaf_hub/main.dart';
import 'package:redleaf_hub/state/hub_state.dart';

// The widget test checks UI interactions, not filesystem discovery. Avoid
// starting real directory scans inside Flutter's fake-async widget-test zone.
class _InMemoryHubState extends HubState {
  @override
  Future<void> scanForProjects() async {
    notifyListeners();
  }
}

Future<_InMemoryHubState> _makeHubState() async {
  SharedPreferences.setMockInitialValues({});
  final state = _InMemoryHubState();

  if (state.isLoading) {
    final ready = Completer<void>();

    void onStateChanged() {
      if (!state.isLoading && !ready.isCompleted) ready.complete();
    }

    state.addListener(onStateChanged);
    try {
      await ready.future.timeout(const Duration(seconds: 5));
    } finally {
      state.removeListener(onStateChanged);
    }
  }

  // Use imaginary paths so that the UI never depends on the test machine's
  // directories. ProjectInspector filesystem behavior is tested separately
  // in project_inspector_test.dart using ordinary (non-widget) unit tests.
  state.homeDirectory = '/virtual/redleaf-projects';
  state.nodeLeafPath = '/virtual/node-leaf';
  state.projects = [
    RedleafProject(name: 'First Archive', path: '/virtual/first-archive'),
    RedleafProject(name: 'Second Dataset', path: '/virtual/second-dataset'),
  ];
  return state;
}

void main() {
  testWidgets('library search and inspector slide open, closed, and open again',
      (WidgetTester tester) async {
    // SharedPreferences uses asynchronous initialization. Complete it outside
    // the widget-test fake clock, then pump the UI with deterministic state.
    final state = await tester.runAsync(_makeHubState);
    expect(state, isNotNull);
    addTearDown(() => state?.dispose());

    await tester.pumpWidget(
      ChangeNotifierProvider<HubState>.value(
        value: state!,
        child: const RedleafHubApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open Project\nLibrary'));
    await tester.pump();

    expect(find.text('First Archive'), findsOneWidget);
    expect(find.text('Second Dataset'), findsOneWidget);

    // The inspector starts closed and is not built until first opened.
    expect(find.byTooltip('Show inspector'), findsOneWidget);
    expect(find.text('REDLEAF TAGS'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'second');
    await tester.pump();

    expect(find.text('First Archive'), findsNothing);
    expect(find.text('Second Dataset'), findsOneWidget);

    // Open from the top toolbar; don't wait for filesystem-backed metadata
    // or indefinite loading indicators using pumpAndSettle().
    await tester.tap(find.byTooltip('Show inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('REDLEAF TAGS'), findsOneWidget);
    expect(find.text('RLINK LOCATIONS'), findsOneWidget);
    expect(find.text('PROJECT NOTES'), findsOneWidget);
    expect(find.byTooltip('Close inspector'), findsOneWidget);

    // Closing moves the drawer horizontally outside the viewport, while
    // leaving the current project selected and retaining its notes editor.
    await tester.tap(find.byTooltip('Close inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Show inspector'), findsOneWidget);
    final hiddenX = tester.getTopLeft(find.text('Project Info')).dx;
    expect(hiddenX, greaterThanOrEqualTo(tester.view.physicalSize.width /
        tester.view.devicePixelRatio));

    // The top toolbar can reopen it, without reselecting the project.
    await tester.tap(find.byTooltip('Show inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Close inspector'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
