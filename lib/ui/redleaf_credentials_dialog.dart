// lib/ui/redleaf_credentials_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/redleaf_project_identity_service.dart';
import '../services/redleaf_shared_credential_vault.dart';
import '../state/hub_state.dart';

/// One project's saved Redleaf login, stored in the operating system keyring.
/// No password is written to Hub settings, workspace data or logs.
class RedleafCredentialsDialog extends StatefulWidget {
  const RedleafCredentialsDialog({
    super.key,
    required this.project,
    this.identity,
    this.vault,
  });

  final RedleafProject project;
  final RedleafProjectIdentityService? identity;
  final RedleafSharedCredentialVault? vault;

  @override
  State<RedleafCredentialsDialog> createState() =>
      _RedleafCredentialsDialogState();
}

class _RedleafCredentialsDialogState
    extends State<RedleafCredentialsDialog> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late final RedleafProjectIdentityService _identity =
      widget.identity ?? RedleafProjectIdentityService();
  late final RedleafSharedCredentialVault _vault =
      widget.vault ?? RedleafSharedCredentialVault();

  String? _instanceId;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _saved = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = await _identity.readInstanceId(widget.project.path);
      final stored = await _vault.read(id);
      if (!mounted) return;
      setState(() {
        _instanceId = id;
        _saved = stored != null;
        _username.text = stored?.username ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    final id = _instanceId;
    if (id == null || _busy) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter a username and password to save.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _vault.save(
        instanceId: id,
        username: _username.text,
        password: _password.text,
        serverUrl: RedleafSharedCredentialVault.defaultServerUrl,
      );
      _password.clear();
      if (!mounted) return;
      setState(() => _saved = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final id = _instanceId;
    if (id == null || _busy || !_saved) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved Redleaf login?'),
        content: const Text(
          'This removes the saved username and password from your desktop '
          'keyring. It does not affect the Redleaf database or MLT Player '
          'project. You will need to sign in manually next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('REMOVE LOGIN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _vault.delete(id);
      if (!mounted) return;
      _password.clear();
      setState(() {
        _saved = false;
        _username.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redleaf Credentials'),
      content: SizedBox(
        width: 475,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.project.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Save this Redleaf login to your Linux desktop keyring. '
                'When launching MLT Player from Hub, MLT Player will use '
                'the saved credentials for this exact database.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const LinearProgressIndicator(minHeight: 2)
              else ...[
                Text(
                  _saved
                      ? 'Login saved in your desktop keyring'
                      : 'No saved login for this project',
                  style: TextStyle(
                    color: _saved
                        ? const Color(0xFF73D52C)
                        : Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  enabled: !_busy && _instanceId != null,
                  decoration: const InputDecoration(
                    labelText: 'Redleaf username',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_busy && _instanceId != null,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _saved
                        ? 'New password (required to replace saved login)'
                        : 'Redleaf password',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () => setState(
                        () => _showPassword = !_showPassword,
                      ),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Saved credentials are only used for the local Redleaf '
                  'server at http://127.0.0.1:5000. Saving replaces any '
                  'previous login for this database. Redleaf will verify '
                  'the password when MLT Player connects.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_saved)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: const Text('REMOVE SAVED LOGIN'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
        FilledButton.icon(
          onPressed: _loading || _busy || _instanceId == null ? null : _save,
          icon: const Icon(Icons.lock_outline),
          label: Text(_busy ? 'SAVING…' : 'SAVE LOGIN'),
        ),
      ],
    );
  }
}
