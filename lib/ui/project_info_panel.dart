import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/hub_state.dart';
import '../state/project_inspector.dart';

/// Offline project details. Notes and broken-link fixes are persisted to the
/// selected project directory, never to Hub's global preferences.
class ProjectInfoPanel extends StatefulWidget {
  const ProjectInfoPanel({
    super.key,
    required this.project,
    this.condaEnv,
  });

  final RedleafProject project;
  final String? condaEnv;

  @override
  State<ProjectInfoPanel> createState() => _ProjectInfoPanelState();
}

class _ProjectInfoPanelState extends State<ProjectInfoPanel> {
  final TextEditingController _notesController = TextEditingController();
  ProjectMetadata? _metadata;
  Timer? _notesTimer;
  Future<void> _writeQueue = Future<void>.value();
  String? _pendingNotes;
  String? _pendingPath;
  String _noteStatus = '';
  String? _metadataError;
  bool _notesLoading = true;
  bool _metadataLoading = true;
  int _loadVersion = 0;
  int _metadataRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void didUpdateWidget(covariant ProjectInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.path != widget.project.path) {
      _flushPendingNotes();
      _loadProject();
    }
  }

  @override
  void dispose() {
    _flushPendingNotes();
    _notesTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _loadProject() {
    final path = widget.project.path;
    final version = ++_loadVersion;
    _notesController.clear();
    _notesLoading = true;
    _metadata = null;
    _metadataError = null;
    _metadataLoading = true;
    _noteStatus = '';

    unawaited(_loadNotes(path, version));
    unawaited(_refreshMetadata(version: version));
  }

  Future<void> _loadNotes(String path, int version) async {
    try {
      final notes = await ProjectInspector.readNotes(path);
      if (!mounted || version != _loadVersion) return;
      _notesController.text = notes;
      setState(() {
        _notesLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _notesLoading = false;
        _noteStatus = 'Could not load notes: $error';
      });
    }
  }

  Future<void> _refreshMetadata({int? version}) async {
    final requestVersion = version ?? _loadVersion;
    final metadataRequest = ++_metadataRequestVersion;
    final path = widget.project.path;
    setState(() {
      _metadataLoading = true;
      _metadataError = null;
    });
    try {
      final metadata = await ProjectInspector.load(
        path,
        condaEnv: widget.condaEnv,
      );
      if (!mounted || requestVersion != _loadVersion ||
          metadataRequest != _metadataRequestVersion) {
        return;
      }
      setState(() {
        _metadata = metadata;
        _metadataLoading = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _loadVersion ||
          metadataRequest != _metadataRequestVersion) {
        return;
      }
      setState(() {
        _metadataError = error.toString();
        _metadataLoading = false;
      });
    }
  }

  void _onNotesChanged(String text) {
    _notesTimer?.cancel();
    _pendingPath = widget.project.path;
    _pendingNotes = text;
    setState(() => _noteStatus = 'Unsaved changes');
    _notesTimer = Timer(const Duration(milliseconds: 650), _flushPendingNotes);
  }

  void _flushPendingNotes() {
    _notesTimer?.cancel();
    final path = _pendingPath;
    final notes = _pendingNotes;
    _pendingPath = null;
    _pendingNotes = null;
    if (path == null || notes == null) return;

    // Serialize writes, including when the user switches projects quickly.
    _writeQueue = _writeQueue
        .then((_) => ProjectInspector.saveNotes(path, notes))
        .then((_) {
          if (mounted && widget.project.path == path &&
              _pendingNotes == null) {
            setState(() => _noteStatus = 'Saved locally');
          }
        })
        .catchError((Object error) {
          if (mounted && widget.project.path == path) {
            setState(() => _noteStatus = 'Save failed: $error');
          }
        });
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Path copied')),
      );
    }
  }

  Future<void> _openDirectory(String path) async {
    try {
      final uri = Uri.file(path, windows: Platform.isWindows);
      if (!await launchUrl(uri)) {
        throw Exception('No file manager accepted this location');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open directory: $error')),
      );
    }
  }

  Future<void> _repairLink(RedleafLink link) async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Locate directory for ${link.alias}',
    );
    if (chosen == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${link.alias}?'),
        content: SingleChildScrollView(
          child: Text(
            'Current location:\n'
            '${link.targetPath.isEmpty ? "(no location)" : link.targetPath}'
            '\n\nNew location:\n$chosen'
            '\n\nThis changes the .rlink file in your Redleaf documents folder.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update link'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ProjectInspector.updateLink(link, chosen);
      if (!mounted) return;
      await _refreshMetadata();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${link.alias} now points to $chosen')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update link: $error')),
      );
    }
  }

  Widget _sectionHeading(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFA22323)),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final metadata = _metadata;
    if (metadata == null) return const SizedBox.shrink();
    if (metadata.tagsMessage != null) {
      return Text(
        metadata.tagsMessage!,
        style: const TextStyle(color: Colors.amber, fontSize: 12),
      );
    }
    if (metadata.tags.isEmpty) {
      return const Text(
        'No tags in this Redleaf database.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final tag in metadata.tags)
          Tooltip(
            message: '${tag.documentCount} tagged documents',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF272731),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF41414C)),
              ),
              child: Text(
                '${tag.name}  ${tag.documentCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinks() {
    final metadata = _metadata;
    if (metadata == null) return const SizedBox.shrink();
    if (metadata.links.isEmpty) {
      return const Text(
        'No .rlink folders configured.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    return Column(
      children: [
        for (final link in metadata.links)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF202027),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: link.isAvailable
                    ? const Color(0xFF343A39)
                    : const Color(0xFF865247),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      link.isAvailable ? Icons.check_circle : Icons.error_outline,
                      size: 16,
                      color: link.isAvailable
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        link.alias,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy target path',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyPath(link.targetPath),
                    ),
                    if (link.isAvailable)
                      IconButton(
                        tooltip: 'Open linked directory',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        onPressed: () => _openDirectory(link.targetPath),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  link.targetPath.isEmpty
                      ? '(No target path recorded)'
                      : link.targetPath,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (link.readError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      link.readError!,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (!link.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Folder missing',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _repairLink(link),
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Relocate'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16161C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF383842))),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFA22323)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Project Info',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh tags and RLinks',
                  onPressed: _metadataLoading ? null : _refreshMetadata,
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.project.name,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  widget.project.path,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 26),
                _sectionHeading('REDLEAF TAGS', Icons.sell_outlined),
                if (_metadataLoading)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else if (_metadataError != null)
                  Text(_metadataError!, style: const TextStyle(color: Colors.orangeAccent))
                else
                  _buildTags(),
                const SizedBox(height: 30),
                _sectionHeading('RLINK LOCATIONS', Icons.folder_copy_outlined),
                if (_metadataLoading)
                  const Text(
                    'Checking external folders…',
                    style: TextStyle(color: Colors.white54),
                  )
                else if (_metadataError != null)
                  Text(_metadataError!, style: const TextStyle(color: Colors.orangeAccent))
                else ...[
                  if ((_metadata?.missingLinks ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${_metadata!.missingLinks} linked folder(s) need attention',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                      ),
                    ),
                  _buildLinks(),
                ],
                const SizedBox(height: 26),
                _sectionHeading('PROJECT NOTES', Icons.edit_note_outlined),
                if (_notesLoading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  TextField(
                    controller: _notesController,
                    onChanged: _onNotesChanged,
                    minLines: 7,
                    maxLines: 16,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Research context, reminders, next steps…',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Color(0xFF0E0E12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _noteStatus.isEmpty
                      ? 'Saved automatically in this project directory'
                      : _noteStatus,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
