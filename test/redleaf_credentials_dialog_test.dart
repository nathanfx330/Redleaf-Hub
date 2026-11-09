// test/redleaf_credentials_dialog_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redleaf_hub/services/redleaf_project_identity_service.dart';
import 'package:redleaf_hub/services/redleaf_shared_credential_vault.dart';
import 'package:redleaf_hub/state/hub_state.dart';
import 'package:redleaf_hub/ui/redleaf_credentials_dialog.dart';

class _Identity extends RedleafProjectIdentityService {
  @override
  Future<String> readInstanceId(String projectFolder) async =>
      'canonical-database-1';
}

class _FakeVault extends RedleafSharedCredentialVault {
  _FakeVault() : super(storageDirectory: Directory('/not-used'));

  RedleafSavedCredentials? saved;
  int saves = 0;
  int clears = 0;

  @override
  Future<RedleafSavedCredentials?> read(String instanceId) async {
    expect(instanceId, 'canonical-database-1');
    return saved;
  }

  @override
  Future<void> save({
    required String instanceId,
    required String username,
    required String password,
    String serverUrl = RedleafSharedCredentialVault.defaultServerUrl,
  }) async {
    expect(instanceId, 'canonical-database-1');
    saves += 1;
    saved = RedleafSavedCredentials(
      username: username,
      password: password,
      serverUrl: serverUrl,
    );
  }

  @override
  Future<void> delete(String instanceId) async {
    expect(instanceId, 'canonical-database-1');
    clears += 1;
    saved = null;
  }
}

void main() {
  testWidgets('Hub saves and removes one project login from its built-in vault',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vault = _FakeVault();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              child: const Text('MANAGE'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => RedleafCredentialsDialog(
                  project: RedleafProject(
                    name: 'My Redleaf Archive',
                    path: '/unused/testing/path',
                  ),
                  identity: _Identity(),
                  vault: vault,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MANAGE'));
    await tester.pumpAndSettle();
    expect(find.text('No saved login for this project'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'editor');
    await tester.enterText(fields.at(1), 'private-redleaf-password');
    await tester.tap(find.text('SAVE LOGIN'));
    await tester.pumpAndSettle();

    expect(vault.saves, 1);
    expect(find.text('Login saved in the private local vault'), findsOneWidget);
    expect(vault.saved?.username, 'editor');
    expect(vault.saved?.password, 'private-redleaf-password');
    expect(find.text('private-redleaf-password'), findsNothing);

    final remove = find.text('REMOVE SAVED LOGIN');
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove saved Redleaf login?'), findsOneWidget);

    await tester.tap(find.text('REMOVE LOGIN'));
    await tester.pumpAndSettle();
    expect(vault.clears, 1);
    expect(vault.saved, isNull);
    expect(find.text('No saved login for this project'), findsOneWidget);
  });
}
