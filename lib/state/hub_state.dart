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
  String? condaEnv; 
  String templateGitUrl = 'https://github.com/nathanfx330/redleaf.git'; // --- NEW: Dynamic Git URL ---
  
  List<RedleafProject> projects = [];
  bool isLoading = true;

  // --- SERVER TRACKING ---
  RedleafProject? activeProject;
  bool _isServerResponding = false;
  Timer? _pingTimer;
  int _failedPingCount = 0; // Tracks consecutive failures
  
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
  
  Future<void> saveSettings(String homeDir, String nodePath, String? conda, String gitUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homeDirectory', homeDir);
    await prefs.setString('nodeLeafPath', nodePath);
    await prefs.setString('templateGitUrl', gitUrl); // Save Git URL
    
    if (conda != null && conda.isNotEmpty) {
      await prefs.setString('condaEnv', conda);
    } else {
      await prefs.remove('condaEnv');
    }
    
    homeDirectory = homeDir;
    nodeLeafPath = nodePath;
    condaEnv = conda;
    templateGitUrl = gitUrl;
    
    await scanForProjects();
    await checkTemplateStatus();
    notifyListeners();
  }

  // Completely wipe the app state and return to setup screen
  Future<void> resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    homeDirectory = null;
    nodeLeafPath = null;
    condaEnv = null;
    templateGitUrl = 'https://github.com/nathanfx330/redleaf.git'; // Reset to default
    projects.clear();
    isTemplateReady = false;
    unlinkServer(); // Cancels the timer and drops the active project
    
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
      // Use the dynamic URL
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
    _failedPingCount = 0; // Reset failure count on new launch
    notifyListeners();

    try {
      String commandString;
      if (condaEnv != null && condaEnv!.isNotEmpty) {
        if (Platform.isWindows) {
          commandString = 'conda activate $condaEnv && python run.py';
        } else {
          commandString = 'eval "\$(conda shell.bash hook)" && conda activate $condaEnv && python3 run.py';
        }
      } else {
        commandString = Platform.isWindows ? 'python run.py' : 'python3 run.py';
      }

      if (Platform.isLinux) {
        await Process.start(
          'gnome-terminal', 
          ['--', 'bash', '-c', '$commandString; echo ""; echo "Server Stopped."; read -p "Press Enter to close..."'], 
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
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 1);
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:5000/'));
        final response = await request.close();
        
        // Success! Reset failure count and ensure UI is green
        _failedPingCount = 0;
        if (!_isServerResponding) {
          _isServerResponding = true;
          notifyListeners();
        }
      } catch (e) {
        // Ping failed.
        _failedPingCount++;
        
        // If it fails 3 times in a row (6 seconds total), assume terminal was closed
        if (_failedPingCount >= 3) {
          debugPrint("Server stopped responding. Auto-unlinking UI.");
          unlinkServer();
        } else if (_isServerResponding) {
          // If it just failed once but was previously green, turn it amber immediately
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