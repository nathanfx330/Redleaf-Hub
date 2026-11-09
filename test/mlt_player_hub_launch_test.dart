// test/mlt_player_hub_launch_test.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redleaf_hub/state/hub_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HubState> loadHubState() async {
  final state = HubState();
  if (!state.isLoading) return state;

  final ready = Completer<void>();
  void changed() {
    if (!state.isLoading && !ready.isCompleted) ready.complete();
  }

  state.addListener(changed);
  try {
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    state.removeListener(changed);
  }
  return state;
}

void main() {
  test('Hub launcher passes selected folder and URL, never credentials', () {
    final project = RedleafProject(
      name: 'WWI Archive',
      path: '/media/redleaf/WWI Archive',
    );

    final args = HubState.mltPlayerLaunchArguments(project);
    expect(args, <String>[
      '--redleaf-hub-project-path',
      '/media/redleaf/WWI Archive',
      '--redleaf-hub-server-url',
      'http://127.0.0.1:5000',
    ]);
    expect(args.join(' '), isNot(contains('password')));
    expect(args.join(' '), isNot(contains('cookie')));
    expect(args.join(' '), isNot(contains('username')));

    expect(
      HubState.mltPlayerLaunchArguments(
        project,
        serverUrl: 'http://localhost:5010',
      ).last,
      'http://localhost:5010',
    );
  });

  test('optional MLT Player path persists without changing required setup',
      () async {
    SharedPreferences.setMockInitialValues({});
    final home = await Directory.systemTemp.createTemp('hub_mlt_path_test_');
    addTearDown(() => home.delete(recursive: true));

    final first = await loadHubState();
    expect(first.mltPlayerPath, isNull);
    expect(first.isSetupComplete, isFalse);

    await first.saveSettings(
      home.path,
      '/bin/node-leaf',
      null,
      'https://github.com/nathanfx330/redleaf.git',
      mltPlayerExecutable: '/opt/MLT Player/mlt_player',
    );
    expect(first.isSetupComplete, isTrue);
    expect(first.mltPlayerPath, '/opt/MLT Player/mlt_player');

    final reopened = await loadHubState();
    expect(reopened.mltPlayerPath, '/opt/MLT Player/mlt_player');
    expect(reopened.isSetupComplete, isTrue);

    await reopened.saveSettings(
      home.path,
      '/bin/node-leaf',
      null,
      'https://github.com/nathanfx330/redleaf.git',
      mltPlayerExecutable: '',
    );
    expect(reopened.mltPlayerPath, isNull);
    expect(reopened.isSetupComplete, isTrue);

    first.dispose();
    reopened.dispose();
  });

  test('Hub refuses MLT launch unless Redleaf server is active', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await loadHubState();
    addTearDown(state.dispose);

    state
      ..mltPlayerPath = '/virtual/mlt_player'
      ..activeProject = RedleafProject(
        name: 'Archive',
        path: '/virtual/archive',
      );

    await expectLater(
      state.launchMltPlayer(),
      throwsA(isA<StateError>()),
    );
  });
}
