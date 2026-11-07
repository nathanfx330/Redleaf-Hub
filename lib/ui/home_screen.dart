// --- File: lib/ui/home_screen.dart ---
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../state/hub_state.dart';
import 'setup_screen.dart';
import 'project_info_panel.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProjectPath;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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

  // On smaller windows, the project details become a dialog rather than
  // squeezing the project controls into an unusably narrow list.
  void _selectProject(RedleafProject project) {
    setState(() => _selectedProjectPath = project.path);
    if (MediaQuery.sizeOf(context).width < 1050) {
      final conda = context.read<HubState>().condaEnv;
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF16161C),
          child: SizedBox(
            width: 460,
            height: MediaQuery.sizeOf(ctx).height * 0.84,
            child: ProjectInfoPanel(project: project, condaEnv: conda),
          ),
        ),
      );
    }
  }

  // --- UI: SEARCHABLE PROJECT LIBRARY ---
  Widget _buildLibrary(HubState hubState) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleProjects = hubState.projects.where((project) {
      return project.name.toLowerCase().contains(query) ||
          project.path.toLowerCase().contains(query);
    }).toList();

    RedleafProject? selectedProject;
    for (final project in visibleProjects) {
      if (project.path == _selectedProjectPath) {
        selectedProject = project;
        break;
      }
    }
    if (selectedProject == null && visibleProjects.isNotEmpty) {
      selectedProject = visibleProjects.first;
    }

    return Column(
      children: [
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
              const Text(
                'Project Library',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: 'Scan for folders',
                onPressed: () => hubState.scanForProjects(),
              ),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF101015),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    setState(() {});
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search projects by name or path…',
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFF22222A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${visibleProjects.length} / ${hubState.projects.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar =
                  constraints.maxWidth >= 1050 && selectedProject != null;
              return Row(
                children: [
                  Expanded(
                    child: visibleProjects.isEmpty
                        ? Center(
                            child: Text(
                              hubState.projects.isEmpty
                                  ? 'No Redleaf projects found in your Master Folder.'
                                  : 'No projects match your search.',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          )
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: visibleProjects.length,
                              itemBuilder: (context, index) {
                                final project = visibleProjects[index];
                                final isActive = hubState.activeProject?.path == project.path;
                                return _ProjectListItem(
                                  key: ValueKey(project.path),
                                  project: project,
                                  isActiveProject: isActive,
                                  isOnline: isActive && hubState.isServerRunning,
                                  isSelected: project.path == selectedProject?.path,
                                  bgColor: index.isEven
                                      ? const Color(0xFF0A0A0A)
                                      : const Color(0xFF111111),
                                  hubState: hubState,
                                  onSelect: () => _selectProject(project),
                                );
                              },
                            ),
                          ),
                  ),
                  if (showSidebar)
                    SizedBox(
                      width: 390,
                      child: ProjectInfoPanel(
                        key: ValueKey(selectedProject.path),
                        project: selectedProject,
                        condaEnv: hubState.condaEnv,
                      ),
                    ),
                ],
              );
            },
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

// The project row is selectable without losing its existing folder/server
// actions. Wrapping the actions keeps it usable beside the info panel.
class _ProjectListItem extends StatefulWidget {
  const _ProjectListItem({
    super.key,
    required this.project,
    required this.isActiveProject,
    required this.isOnline,
    required this.isSelected,
    required this.bgColor,
    required this.hubState,
    required this.onSelect,
  });

  final RedleafProject project;
  final bool isActiveProject;
  final bool isOnline;
  final bool isSelected;
  final Color bgColor;
  final HubState hubState;
  final VoidCallback onSelect;

  @override
  State<_ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends State<_ProjectListItem> {
  bool _isHoveringRoot = false;
  bool _isHoveringDocs = false;

  Future<void> _openDirectory(String path) async {
    try {
      final uri = Uri.file(path, windows: Platform.isWindows);
      if (!await launchUrl(uri)) {
        throw Exception('No file manager accepted the location');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open folder: $path ($error)'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _folderButton({
    required String label,
    required IconData icon,
    required bool hovering,
    required ValueChanged<bool> setHover,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      onEnter: (_) => setHover(true),
      onExit: (_) => setHover(false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: hovering ? 1.0 : 0.6,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF383842)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActiveProject;
    final isOnline = widget.isOnline;
    return Material(
      color: widget.isSelected
          ? const Color(0xFF22222D)
          : widget.bgColor,
      child: InkWell(
        onTap: widget.onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? const Color(0xFF4FC1FF)
                    : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: Color(0xFF24242B)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder,
                    size: 27,
                    color: isActive
                        ? (isOnline ? Colors.greenAccent : Colors.amber)
                        : const Color(0xFFA22323),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Tooltip(
                          message: widget.project.path,
                          child: Text(
                            widget.project.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF828290),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Project information',
                    icon: Icon(
                      Icons.info_outline,
                      color: widget.isSelected
                          ? const Color(0xFF4FC1FF)
                          : Colors.white54,
                    ),
                    onPressed: widget.onSelect,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: isOnline ? Colors.greenAccent : Colors.amber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOnline ? 'Online' : 'Waiting for Server…',
                            style: TextStyle(
                              color: isOnline ? Colors.greenAccent : Colors.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _folderButton(
                    label: 'Root',
                    icon: Icons.source,
                    hovering: _isHoveringRoot,
                    setHover: (value) => setState(() => _isHoveringRoot = value),
                    onPressed: () => _openDirectory(widget.project.path),
                  ),
                  _folderButton(
                    label: 'Documents',
                    icon: Icons.folder_open,
                    hovering: _isHoveringDocs,
                    setHover: (value) => setState(() => _isHoveringDocs = value),
                    onPressed: () => _openDirectory(
                      p.join(widget.project.path, 'documents'),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive
                          ? const Color(0xFF383842)
                          : const Color(0xFFA22323),
                    ),
                    onPressed: () {
                      if (isActive) {
                        widget.hubState.unlinkServer();
                      } else {
                        widget.hubState.startProjectServer(widget.project);
                      }
                    },
                    child: Text(isActive ? 'Unlink UI' : 'Pop Terminal Server'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                color: Colors.black.withValues(alpha: 0.5),
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