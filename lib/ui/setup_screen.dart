import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _selectedHomeDir;
  String? _selectedNodePath;
  String? _selectedMltPlayerPath;
  final TextEditingController _condaCtrl = TextEditingController();
  final TextEditingController _gitUrlCtrl = TextEditingController(); 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing existing settings
    final hubState = context.read<HubState>();
    _selectedHomeDir = hubState.homeDirectory;
    _selectedNodePath = hubState.nodeLeafPath;
    _selectedMltPlayerPath = hubState.mltPlayerPath;
    
    if (hubState.condaEnv != null) {
      _condaCtrl.text = hubState.condaEnv!;
    }
    
    // Always populate the Git URL (it falls back to default in State if empty)
    _gitUrlCtrl.text = hubState.templateGitUrl;
  }

  @override
  void dispose() {
    _condaCtrl.dispose();
    _gitUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory(Function(String) onSelected, String title) async {
    String? result = await FilePicker.platform.getDirectoryPath(dialogTitle: title);
    if (result != null) setState(() => onSelected(result));
  }

  Future<void> _pickNodeLeaf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Node Leaf Executable', type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedNodePath = result.files.single.path!);
    }
  }

  Future<void> _pickMltPlayer() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select MLT Player Executable',
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedMltPlayerPath = result.files.single.path!);
    }
  }

  void _finishSetup() async {
    if (_selectedHomeDir == null || _selectedNodePath == null) return;
    
    // Ensure the user didn't wipe the Git URL completely
    if (_gitUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Template Git URL cannot be empty."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final condaEnv = _condaCtrl.text.trim();
    final gitUrl = _gitUrlCtrl.text.trim();
    
    await context.read<HubState>().saveSettings(
      _selectedHomeDir!, 
      _selectedNodePath!, 
      condaEnv.isNotEmpty ? condaEnv : null,
      gitUrl,
      mltPlayerExecutable: _selectedMltPlayerPath ?? '',
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    // If editing from the home screen, we need to pop the navigator
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildFileRow(String title, String? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF383842)),
                ),
                child: Text(
                  value ?? "Choose path...",
                  style: TextStyle(color: value == null ? const Color(0xFF828290) : Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF383842)),
              onPressed: onTap,
              child: const Text("Browse"),
            ),
          ],
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _selectedHomeDir != null && _selectedNodePath != null;
    final isEditing = context.read<HubState>().isSetupComplete;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isEditing ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      // --- FIX: SingleChildScrollView wraps Center, pushing scrollbar to window edge ---
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: theme.cardColor, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF383842)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Icon(Icons.hub_outlined, size: 64, color: theme.colorScheme.primary)),
                const SizedBox(height: 20),
                Center(child: Text(isEditing ? "Settings" : "Welcome to Redleaf Hub", style: theme.textTheme.titleLarge)),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    isEditing 
                      ? "Update your studio paths and environment configurations."
                      : "Let's configure your studio paths to enable offline, local-first project generation.", 
                    textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF828290), height: 1.5)
                  ),
                ),
                const SizedBox(height: 40),
                
                _buildFileRow(
                  "1. Master Projects Folder\n(Where your new databases will live)", 
                  _selectedHomeDir, 
                  () => _pickDirectory((p) => _selectedHomeDir = p, "Select Master Projects Folder")
                ),
                
                _buildFileRow(
                  "2. Node Leaf Executable\n(The visual canvas app)", 
                  _selectedNodePath, 
                  _pickNodeLeaf
                ),

                _buildFileRow(
                  "MLT Player Executable (Optional)\n(Launch the selected Redleaf project in MLT Player)",
                  _selectedMltPlayerPath,
                  _pickMltPlayer,
                ),
                if (_selectedMltPlayerPath != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _selectedMltPlayerPath = null),
                      child: const Text('CLEAR MLT PLAYER PATH'),
                    ),
                  ),

                const SizedBox(height: 10),
                Text("3. Conda Environment (Optional)", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                const Text("If you use Conda, enter the environment name (e.g. 'redleaf-env'). The Hub will automatically activate it before starting your servers.", style: TextStyle(color: Color(0xFF828290), fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: _condaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "e.g., redleaf-env",
                    hintStyle: const TextStyle(color: Color(0xFF828290)),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF383842)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF383842)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),

                Text("4. Redleaf Template Source URL", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                const Text("The git repository to clone when updating the master template. Change this if you have a private fork of Redleaf.", style: TextStyle(color: Color(0xFF828290), fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: _gitUrlCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "https://github.com/...",
                    hintStyle: const TextStyle(color: Color(0xFF828290)),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF383842)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF383842)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSave && !_isLoading ? _finishSetup : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), disabledBackgroundColor: const Color(0xFF383842)),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                if (isEditing) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E24),
                            title: const Text("Reset Redleaf Hub?", style: TextStyle(color: Colors.redAccent)),
                            content: const Text("This will clear your saved paths and settings. Your actual project folders and documents will NOT be deleted.", style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false), 
                                child: const Text("Cancel", style: TextStyle(color: Colors.white54))
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(ctx, true), 
                                child: const Text("Reset Hub")
                              ),
                            ],
                          )
                        );
                        
                        if (confirm == true) {
                          if (!context.mounted) return;
                          final hubState = context.read<HubState>();
                          await hubState.resetApp();
                          if (!context.mounted) return;
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                      child: const Text("Reset Hub Settings"),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}