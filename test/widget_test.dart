// test/widget_test.dart

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

class _OnlineMltHubState extends _InMemoryHubState {
  int launches = 0;

  @override
  bool get isServerRunning => true;

  @override
  Future<void> launchMltPlayer() async {
    launches += 1;
  }
}

Future<_InMemoryHubState> _makeHubState({
  _InMemoryHubState? existing,
}) async {
  SharedPreferences.setMockInitialValues({});
  final state = existing ?? _InMemoryHubState();

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
    // Use a desktop-size viewport so the project info icon stays accessible
    // while the side panel is open, just like the real Linux desktop app.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // Creation and settings remain on the unchanged Home screen.
    expect(find.text('Create New\nRedleaf Repo'), findsOneWidget);
    expect(find.byTooltip('Settings & Paths'), findsOneWidget);

    await tester.tap(find.text('Open Project\nLibrary'));
    await tester.pump();

    expect(find.text('Redleaf Hub'), findsOneWidget);
    expect(find.text('Project Library'), findsOneWidget);
    expect(find.byTooltip('Back to home'), findsOneWidget);
    // Never substitute a generic leaf for the app's real logo. The Back
    // arrow should instead be the leftmost control, before the app title.
    expect(find.byIcon(Icons.eco_outlined), findsNothing);
    final homeX = tester.getTopLeft(find.byTooltip('Back to home')).dx;
    final titleX = tester.getTopLeft(find.text('Redleaf Hub')).dx;
    expect(homeX, lessThan(titleX));
    expect(find.textContaining('Add Project'), findsNothing);
    expect(find.text('Create New\nRedleaf Repo'), findsNothing);
    expect(find.text('First Archive'), findsOneWidget);
    expect(find.text('Second Dataset'), findsOneWidget);

    final searchInput = tester.widget<TextField>(find.byType(TextField).first);
    expect(searchInput.decoration?.hintText, 'Search projects…');
    expect(searchInput.decoration?.hintMaxLines, 1);
    expect(searchInput.textAlignVertical, TextAlignVertical.center);

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
    final viewportWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final startingX = tester.getTopLeft(find.text('Project Info')).dx;
    expect(startingX, greaterThanOrEqualTo(viewportWidth));
    await tester.pump(const Duration(milliseconds: 350));
    final openedX = tester.getTopLeft(find.text('Project Info')).dx;
    expect(openedX, lessThan(viewportWidth));

    expect(find.text('REDLEAF TAGS'), findsOneWidget);
    expect(find.text('RLINK LOCATIONS'), findsOneWidget);
    expect(find.text('PROJECT NOTES'), findsOneWidget);
    expect(find.byTooltip('Hide inspector'), findsOneWidget);

    // Closing moves the drawer horizontally outside the viewport, while
    // leaving the current project selected and retaining its notes editor.
    await tester.tap(find.byTooltip('Hide inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Show inspector'), findsOneWidget);
    final hiddenX = tester.getTopLeft(find.text('Project Info')).dx;
    expect(hiddenX, greaterThanOrEqualTo(viewportWidth));

    // The top toolbar can reopen it, without reselecting the project.
    await tester.tap(find.byTooltip('Show inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Hide inspector'), findsOneWidget);

    // Clicking the project NAME (the row's InkWell) closes the drawer.
    await tester.tap(find.text('Second Dataset').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Show inspector'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Project Info')).dx,
      greaterThanOrEqualTo(viewportWidth),
    );

    // The same row toggles it open, using the existing horizontal slide.
    await tester.tap(find.text('Second Dataset').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Hide inspector'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Project Info')).dx,
      lessThan(viewportWidth),
    );

    // The information icon still uses the same toggle.
    await tester.tap(find.byTooltip('Project information').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Show inspector'), findsOneWidget);

    // Opening the first project while another was selected switches details.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.text('First Archive').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Hide inspector'), findsOneWidget);
    expect(find.text('First Archive'), findsNWidgets(2));

    // Every folder retains Redleaf red; the list never turns red to mark an
    // active project, and the iTunes-style selected row stays charcoal.
    for (final icon in tester.widgetList<Icon>(find.byIcon(Icons.folder))) {
      expect(icon.color, const Color(0xFFA22323));
    }

    await tester.tap(find.byTooltip('Back to home'));
    await tester.pump();
    expect(find.text('Create New\nRedleaf Repo'), findsOneWidget);
    expect(find.byTooltip('Settings & Paths'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 20)));

  testWidgets('server-online library exposes MLT Player launch beside Node Leaf',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final online = _OnlineMltHubState();
    final loaded = await tester.runAsync(
      () => _makeHubState(existing: online),
    );
    expect(loaded, same(online));
    addTearDown(online.dispose);
    online
      ..mltPlayerPath = '/virtual/mlt-player'
      ..activeProject = online.projects.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<HubState>.value(
        value: online,
        child: const RedleafHubApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open Project\nLibrary'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Launch Node Leaf'), findsOneWidget);
    expect(find.text('Launch MLT Player'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('redleaf-studio-launcher')),
      findsOneWidget,
    );
    final launcher = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('redleaf-studio-launcher')),
    );
    expect(launcher.constraints?.maxHeight, isNull);
    expect(launcher.decoration, isNotNull);
    expect(launcher.duration, const Duration(milliseconds: 300));
    expect(find.text('REDLEAF'), findsOneWidget);
    expect(find.text('ONLINE  ·  localhost:5000'), findsOneWidget);

    await tester.tap(find.text('Launch MLT Player'));
    await tester.pump();
    expect(online.launches, 1);
  }, timeout: const Timeout(Duration(seconds: 20)));

}
