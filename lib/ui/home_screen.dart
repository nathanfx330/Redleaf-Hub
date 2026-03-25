// --- File: lib/ui/home_screen.dart ---
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../state/hub_state.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showLibrary = false;
  bool _isCreatingRepo = false;
  bool _isUpdatingTemplate = false;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGIC: UPDATE TEMPLATE ---
  Future<void> _updateTemplate() async {
    setState(() => _isUpdatingTemplate = true);
    try {
      await context.read<HubState>().fetchOrUpdateTemplate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Master Template is up to date!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text("Error Fetching Template", style: TextStyle(color: Colors.redAccent)),
            content: Text("Ensure Git is installed and you have internet access. Details:\n\n$e", style: const TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white)))],
          )
        );
      }
    } finally {
      setState(() => _isUpdatingTemplate = false);
    }
  }

  // --- LOGIC: CREATE NEW REPO (OFFLINE) ---
  Future<void> _createNewRepo() async {
    final hubState = context.read<HubState>();

    if (!hubState.isTemplateReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please download the Master Template first!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final nameController = TextEditingController();
    
    final String? projectName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text("New Redleaf Project", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g., XYZ_Archive",
            hintStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (projectName == null || projectName.isEmpty) return;

    setState(() => _isCreatingRepo = true);

    try {
      await hubState.createProjectFromTemplate(projectName);
      
      setState(() {
        _showLibrary = true;
        _isCreatingRepo = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Project '$projectName' generated successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isCreatingRepo = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text("Error Creating Repo", style: TextStyle(color: Colors.redAccent)),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white)))],
          )
        );
      }
    }
  }

  // --- UI: THE BIG ROUNDED RECTANGLE BUTTONS ---
  Widget _buildMenu() {
    final hubState = context.watch<HubState>();

    return Stack(
      children: [
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54, size: 32),
            tooltip: "Settings & Paths",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SetupScreen()),
              );
            },
          ),
        ),
        
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MenuCard(
                    title: "Create New\nRedleaf Repo",
                    icon: Icons.add_box_outlined,
                    isLoading: _isCreatingRepo,
                    onTap: _createNewRepo,
                  ),
                  const SizedBox(width: 40),
                  _MenuCard(
                    title: "Open Project\nLibrary",
                    icon: Icons.view_list_rounded,
                    onTap: () {
                      context.read<HubState>().scanForProjects();
                      setState(() => _showLibrary = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 60),

              if (hubState.isTemplateReady)
                TextButton.icon(
                  icon: _isUpdatingTemplate 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                      : const Icon(Icons.cloud_sync, color: Colors.white54),
                  label: Text(
                    _isUpdatingTemplate ? "Updating Template..." : "Update Master Template from GitHub", 
                    style: const TextStyle(color: Colors.white54)
                  ),
                  onPressed: _isUpdatingTemplate ? null : _updateTemplate,
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4fc1ff),
                    foregroundColor: Colors.black,
                  ),
                  icon: _isUpdatingTemplate 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.cloud_download),
                  label: Text(
                    _isUpdatingTemplate ? "Downloading..." : "Download Required Master Template",
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  onPressed: _isUpdatingTemplate ? null : _updateTemplate,
                )
            ],
          ),
        ),
      ],
    );
  }

  // --- UI: CANDY-STRIPED PROJECT LIST ---
  Widget _buildLibrary(HubState hubState) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          color: const Color(0xFF1E1E24),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _showLibrary = false),
              ),
              const SizedBox(width: 10),
              const Text("Project Library", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: "Scan for folders",
                onPressed: () => hubState.scanForProjects(),
              ),
            ],
          ),
        ),

        Expanded(
          child: hubState.projects.isEmpty
              ? const Center(child: Text("No Redleaf projects found in your Master Folder.", style: TextStyle(color: Colors.white54)))
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: hubState.projects.length,
                    itemBuilder: (context, index) {
                      final project = hubState.projects[index];
                      final isActiveProject = hubState.activeProject?.path == project.path;
                      final isOnline = isActiveProject && hubState.isServerRunning;
                      final bgColor = index % 2 == 0 ? const Color(0xFF0A0A0A) : const Color(0xFF111111);

                      return _ProjectListItem(
                        project: project,
                        isActiveProject: isActiveProject,
                        isOnline: isOnline,
                        bgColor: bgColor,
                        hubState: hubState,
                      );
                    },
                  ),
                ),
        ),

        // --- STUDIO LAUNCHER BAR ---
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: hubState.isServerRunning ? 80 : 0,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E24),
            border: Border(top: BorderSide(color: Color(0xFF383842))),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Row(
                children: [
                  const Icon(Icons.rocket_launch, color: Color(0xFF4fc1ff)),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      "Server is active. You can safely close the terminal window when you are done.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4fc1ff),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    icon: const Icon(Icons.account_tree),
                    label: const Text("LAUNCH NODE LEAF", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    onPressed: () => hubState.launchNodeLeaf(),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hubState = context.watch<HubState>();
    return Scaffold(
      body: _showLibrary ? _buildLibrary(hubState) : _buildMenu(),
    );
  }
}

// --- NEW WIDGET: Stateful Project List Item to handle hover state ---
class _ProjectListItem extends StatefulWidget {
  final RedleafProject project;
  final bool isActiveProject;
  final bool isOnline;
  final Color bgColor;
  final HubState hubState;

  const _ProjectListItem({
    required this.project,
    required this.isActiveProject,
    required this.isOnline,
    required this.bgColor,
    required this.hubState,
  });

  @override
  State<_ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends State<_ProjectListItem> {
  // Track hovers independently
  bool _isHoveringRoot = false;
  bool _isHoveringDocs = false;

  Future<void> _openRootFolder() async {
    final uri = Uri.file(widget.project.path);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open folder at: ${widget.project.path}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _openDocumentsFolder() async {
    final docsPath = p.join(widget.project.path, 'documents');
    final uri = Uri.file(docsPath);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open folder at: $docsPath"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      child: Row(
        children: [
          Icon(Icons.folder, color: widget.isActiveProject ? (widget.isOnline ? Colors.greenAccent : Colors.amber) : const Color(0xFFA22323), size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.project.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 4),
                Text(widget.project.path, style: const TextStyle(fontSize: 12, color: Color(0xFF828290))),
              ],
            ),
          ),
          
          // Server Status Indicator
          if (widget.isActiveProject)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Row(
                children: [
                  Icon(Icons.circle, color: widget.isOnline ? Colors.greenAccent : Colors.amber, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    widget.isOnline ? "Online" : "Waiting for Server...", 
                    style: TextStyle(color: widget.isOnline ? Colors.greenAccent : Colors.amber, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hover "Root" Button
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringRoot = true),
                onExit: (_) => setState(() => _isHoveringRoot = false),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isHoveringRoot ? 1.0 : 0.3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.source, size: 18),
                      label: const Text("Root"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF383842)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _openRootFolder,
                    ),
                  ),
                ),
              ),

              // Hover "Documents" Button
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringDocs = true),
                onExit: (_) => setState(() => _isHoveringDocs = false),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isHoveringDocs ? 1.0 : 0.3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text("Documents"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF383842)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _openDocumentsFolder,
                    ),
                  ),
                ),
              ),

              // Start/Stop Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isActiveProject ? const Color(0xFF383842) : const Color(0xFFA22323),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (widget.isActiveProject) {
                    widget.hubState.unlinkServer();
                  } else {
                    widget.hubState.startProjectServer(widget.project);
                  }
                },
                child: Text(widget.isActiveProject ? "Unlink UI" : "Pop Terminal Server"),
              )
            ],
          )
        ],
      ),
    );
  }
}

// --- CUSTOM WIDGET: The Rounded Rectangle Menu Card ---
class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: isLoading ? SystemMouseCursors.wait : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF383842), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const CircularProgressIndicator(color: Color(0xFFA22323))
              else
                Icon(icon, size: 80, color: const Color(0xFFA22323)),
              const SizedBox(height: 30),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}