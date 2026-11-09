// test/redleaf_credentials_dialog_test.dart

import 'dart:convert';

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

class _Keyring {
  String? savedSecret;
  int saves = 0;
  int clears = 0;

  Future<SecretToolResult> run(
    List<String> args, {
    String? secret,
  }) async {
    switch (args.first) {
      case 'lookup':
        return SecretToolResult(0, savedSecret ?? '');
      case 'store':
        saves += 1;
        savedSecret = secret;
        return const SecretToolResult(0, '');
      case 'clear':
        clears += 1;
        savedSecret = null;
        return const SecretToolResult(0, '');
    }
    return const SecretToolResult(1, '');
  }
}

void main() {
  testWidgets('Hub saves and removes one project login from the keyring',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final keyring = _Keyring();
    final vault = RedleafSharedCredentialVault(runner: keyring.run);

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

    expect(keyring.saves, 1);
    expect(find.text('Login saved in your desktop keyring'), findsOneWidget);
    final saved = jsonDecode(keyring.savedSecret!)
        as Map<String, dynamic>;
    expect(saved['username'], 'editor');
    expect(saved['password'], 'private-redleaf-password');
    expect(find.text('private-redleaf-password'), findsNothing);

    final remove = find.text('REMOVE SAVED LOGIN');
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove saved Redleaf login?'), findsOneWidget);

    await tester.tap(find.text('REMOVE LOGIN'));
    await tester.pumpAndSettle();
    expect(keyring.clears, 1);
    expect(keyring.savedSecret, isNull);
    expect(find.text('No saved login for this project'), findsOneWidget);
  });
}
