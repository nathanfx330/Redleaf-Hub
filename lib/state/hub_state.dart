// lib/state/hub_state.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class RedleafProject {
  final String name;
  final String path;

  RedleafProject({required this.name, required this.path});
}

class HubState extends ChangeNotifier {
  String? homeDirectory;
  String? nodeLeafPath;
  String? mltPlayerPath;
  String? condaEnv; 
  String templateGitUrl = 'https://github.com/nathanfx330/redleaf.git';
  
  List<RedleafProject> projects = [];
  bool isLoading = true;

  // --- SERVER TRACKING ---
  RedleafProject? activeProject;
  bool _isServerResponding = false;
  Timer? _pingTimer;
  int _failedPingCount = 0; 
  
  // --- TEMPLATE TRACKING ---
  bool isTemplateReady = false;

  bool get isSetupComplete => homeDirectory != null && nodeLeafPath != null;
  bool get isServerRunning => _isServerResponding;

  String get templatePath => homeDirectory != null ? p.join(homeDirectory!, '.redleaf_template') : '';

  HubState() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    homeDirectory = prefs.getString('homeDirectory');
    nodeLeafPath = prefs.getString('nodeLeafPath');
    mltPlayerPath = prefs.getString('mltPlayerPath');
    condaEnv = prefs.getString('condaEnv'); 
    
    final savedGitUrl = prefs.getString('templateGitUrl');
    if (savedGitUrl != null && savedGitUrl.isNotEmpty) {
      templateGitUrl = savedGitUrl;
    }
    
    if (isSetupComplete) {
      await scanForProjects();
      await checkTemplateStatus();
    }
    
    isLoading = false;
    notifyListeners();
  }

  // --- SETTINGS ---
  
  Future<void> saveSettings(
    String homeDir,
    String nodePath,
    String? conda,
    String gitUrl, {
    String? mltPlayerExecutable,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final chosenMltPath = mltPlayerExecutable ?? mltPlayerPath;
    if (chosenMltPath == null || chosenMltPath.trim().isEmpty) {
      await prefs.remove('mltPlayerPath');
    } else {
      await prefs.setString('mltPlayerPath', chosenMltPath.trim());
    }
    await prefs.setString('homeDirectory', homeDir);
    await prefs.setString('nodeLeafPath', nodePath);
    await prefs.setString('templateGitUrl', gitUrl);
    
    if (conda != null && conda.isNotEmpty) {
      await prefs.setString('condaEnv', conda);
    } else {
      await prefs.remove('condaEnv');
    }
    
    homeDirectory = homeDir;
    nodeLeafPath = nodePath;
    mltPlayerPath =
        chosenMltPath == null || chosenMltPath.trim().isEmpty
            ? null
            : chosenMltPath.trim();
    condaEnv = conda;
    templateGitUrl = gitUrl;
    
    await scanForProjects();
    await checkTemplateStatus();
    notifyListeners();
  }

  Future<void> resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    homeDirectory = null;
    nodeLeafPath = null;
    mltPlayerPath = null;
    condaEnv = null;
    templateGitUrl = 'https://github.com/nathanfx330/redleaf.git';
    projects.clear();
    isTemplateReady = false;
    unlinkServer(); 
    
    notifyListeners();
  }

  // --- TEMPLATE & GIT MANAGEMENT ---

  Future<void> checkTemplateStatus() async {
    if (homeDirectory == null) return;
    final file = File(p.join(templatePath, 'run.py'));
    isTemplateReady = await file.exists();
    notifyListeners();
  }

  Future<void> fetchOrUpdateTemplate() async {
    if (homeDirectory == null) throw Exception("Home directory not set.");
    
    final dir = Directory(templatePath);
    
    if (await dir.exists()) {
      final result = await Process.run('git', ['pull'], workingDirectory: templatePath);
      if (result.exitCode != 0) throw Exception(result.stderr);
    } else {
      final result = await Process.run('git', ['clone', templateGitUrl, templatePath]);
      if (result.exitCode != 0) throw Exception(result.stderr);
    }
    
    await checkTemplateStatus();
  }

  Future<void> createProjectFromTemplate(String projectName) async {
    if (!isTemplateReady) throw Exception("Template not downloaded. Please download the template first.");
    
    final targetPath = p.join(homeDirectory!, projectName);
    final targetDir = Directory(targetPath);
    
    if (await targetDir.exists()) {
      throw Exception("A project named '$projectName' already exists.");
    }

    await targetDir.create(recursive: true);
    final sourceDir = Directory(templatePath);

    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity.path.contains('.git')) continue;

      final relativePath = p.relative(entity.path, from: sourceDir.path);
      final newPath = p.join(targetDir.path, relativePath);

      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }

    await scanForProjects();
  }

  // --- PROJECT SCANNING ---
  
  Future<void> scanForProjects() async {
    if (homeDirectory == null) return;
    
    final dir = Directory(homeDirectory!);
    if (!await dir.exists()) return;

    final List<RedleafProject> foundProjects = [];

    final entities = dir.listSync(recursive: false);
    for (var entity in entities) {
      if (entity is Directory) {
        if (p.basename(entity.path) == '.redleaf_template') continue;

        final runPyPath = p.join(entity.path, 'run.py');
        if (await File(runPyPath).exists()) {
          foundProjects.add(RedleafProject(
            name: p.basename(entity.path), 
            path: entity.path
          ));
        }
      }
    }

    projects = foundProjects;
    projects.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  // --- PROCESS MANAGEMENT & HTTP POLLING ---
  
  Future<void> startProjectServer(RedleafProject project) async {
    activeProject = project;
    _failedPingCount = 0; 
    notifyListeners();

    try {
      String commandString;
      if (condaEnv != null && condaEnv!.isNotEmpty) {
        if (Platform.isWindows) {
          commandString = 'conda activate $condaEnv && python run.py';
        } else {
          commandString = 'source ~/.bashrc; eval "\$(conda shell.bash hook)"; conda activate $condaEnv && python3 run.py';
        }
      } else {
        commandString = Platform.isWindows ? 'python run.py' : 'python3 run.py';
      }

      if (Platform.isLinux) {
        await Process.start(
          'gnome-terminal', 
          ['--', 'bash', '-ic', '$commandString; echo ""; echo "Server Stopped."; read -p "Press Enter to close..."'], 
          workingDirectory: project.path,
          mode: ProcessStartMode.detached
        );
      } else if (Platform.isWindows) {
        await Process.start(
          'cmd', 
          ['/c', 'start', 'cmd', '/k', commandString], 
          workingDirectory: project.path,
          mode: ProcessStartMode.detached
        );
      } else if (Platform.isMacOS) {
        await Process.start(
          'open', 
          ['-a', 'Terminal', project.path], 
          mode: ProcessStartMode.detached
        );
      }
      
      debugPrint("Spawned terminal window for ${project.name}");
      _startPingingServer();

    } catch (e) {
      unlinkServer();
      debugPrint("Failed to spawn terminal: $e");
    }
  }

  void _startPingingServer() {
    _pingTimer?.cancel();
    
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (activeProject == null) {
        timer.cancel();
        _isServerResponding = false;
        notifyListeners();
        return;
      }

      try {
        // --- BULLETPROOF FIX: Raw TCP Socket Ping ---
        // Just checks if port 5000 is open, completely ignoring HTTP redirects.
        final socket = await Socket.connect('127.0.0.1', 5000, timeout: const Duration(milliseconds: 500));
        socket.destroy(); // It's alive, close the connection immediately.
        
        _failedPingCount = 0;
        if (!_isServerResponding) {
          _isServerResponding = true;
          notifyListeners();
        }
      } catch (e) {
        _failedPingCount++;
        
        // Give it 4 failures (8 seconds total) to account for slow Conda activation
        if (_failedPingCount >= 4) {
          debugPrint("Server stopped responding. Auto-unlinking UI.");
          unlinkServer();
        } else if (_isServerResponding) {
          _isServerResponding = false;
          notifyListeners();
        }
      }
    });
  }

  void unlinkServer() {
    activeProject = null;
    _isServerResponding = false;
    _failedPingCount = 0;
    _pingTimer?.cancel();
    notifyListeners();
  }

  /// Launch arguments carry project identity context, not passwords or
  /// Redleaf session cookies. MLT Player decides whether to open a cached
  /// snapshot or present its own sign-in and onboarding dialog.
  static List<String> mltPlayerLaunchArguments(
    RedleafProject project, {
    String serverUrl = 'http://127.0.0.1:5000',
  }) {
    if (project.path.trim().isEmpty) {
      throw StateError('The selected Redleaf project has no folder path.');
    }
    return <String>[
      '--redleaf-hub-project-path',
      project.path,
      '--redleaf-hub-server-url',
      serverUrl,
    ];
  }

  Future<void> launchMltPlayer() async {
    final project = activeProject;
    if (!isServerRunning || project == null) {
      throw StateError('Start a Redleaf project server before launching MLT Player.');
    }
    final executable = mltPlayerPath?.trim() ?? '';
    if (executable.isEmpty) {
      throw StateError(
        'Set the MLT Player executable path in Redleaf Hub Settings first.',
      );
    }

    final args = mltPlayerLaunchArguments(project);
    try {
      await Process.start(
        executable,
        args,
        mode: ProcessStartMode.detached,
      );
      debugPrint('Launched MLT Player for ${project.name}.');
    } on ProcessException catch (error) {
      throw StateError(
        'Could not launch MLT Player at "$executable": ${error.message}',
      );
    }
  }

  Future<void> launchNodeLeaf() async {
    if (nodeLeafPath == null || !isServerRunning) return;

    try {
      await Process.start(nodeLeafPath!, [], mode: ProcessStartMode.detached);
      debugPrint("Launched Node Leaf UI!");
    } catch (e) {
      debugPrint("Failed to launch Node Leaf: $e");
    }
  }
}