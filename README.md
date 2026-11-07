# Redleaf Hub

**Redleaf Hub** is the central desktop launcher and project manager for the Redleaf Knowledge Graph ecosystem. Built in Flutter, it acts as the grand orchestrator between your [Redleaf](https://github.com/nathanfx330/redleaf) Python/Flask backend instances and your [Node Leaf](https://github.com/nathanfx330/node-leaf) visual RAG canvas.

Instead of manually managing terminal windows, Python environments, and scattered folders, Redleaf Hub gives you a sleek, dark-themed UI to create, launch, and manage isolated knowledge bases from a single place.

---

## ✨ Key Features

* **Project Library:** A searchable, minimalist list of all your Redleaf knowledge bases, with a project information sidebar.
* **Offline Project Inspector:** Reads document tags directly from each project's `knowledge_base.db` and displays external `.rlink` folder targets with missing-directory warnings and relocation controls.
* **Project Notes:** Automatically saves notes separately for each project in `.redleaf_hub_notes.txt` at that project's root.
* **Offline Project Generation:** Caches a master template of the Redleaf repository locally. Creating a new project clones it directly from your hard drive, completely internet-independent.
* **Smart Server Detection:** Click "Pop Terminal Server" to spawn a native OS terminal running the backend. The Hub silently polls the server and illuminates a green "Online" indicator when the database is unlocked and ready.
* **Node Leaf Integration:** Once a server is live, a launcher bar slides up allowing you to instantly boot your compiled Node Leaf visual canvas.
* **Conda Environment Support:** Automatically injects shell hooks and `conda activate <env>` commands into the terminal before booting the Python server.
* **Custom Fork Support:** Define your own Git URL in the settings to pull down custom enterprise or private forks of the Redleaf engine.

---

## 🚀 Getting Started

### Prerequisites For Building

1. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Desktop support enabled for Linux, Windows, or macOS)
2. **Git** installed and accessible from your system path.
3. **Python 3.9+** (or Conda).

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/nathanfx330/Redleaf-Hub.git
   cd Redleaf-Hub
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run -d linux   # or windows, macos
   ```

4. Build the standalone executable:
   ```bash
   flutter build linux    # Finds the output in build/linux/x64/release/bundle/
   ```

---

## ⚙️ Configuration & Workflow

On the first launch, you will be greeted by the **Setup Screen**. 

1. **Master Projects Folder:** Select an empty folder on your hard drive where all future Redleaf databases will live.
2. **Node Leaf Executable:** Point the Hub to the compiled binary of your Node Leaf canvas (e.g., `.../build/linux/x64/release/bundle/node_leaf`).
3. **Conda Environment (Optional):** If your Redleaf Python dependencies live inside a Conda environment, type the name here (e.g., `redleaf-env`).
4. **Template Git URL:** The default Redleaf repository URL. Change this if you maintain a private fork.

**The Workflow:**
1. Click **Download Required Master Template** to pull the engine down to your hidden cache.
2. Click **Create New Redleaf Repo** to spin up an isolated, offline instance.
3. Click **Pop Terminal Server** on your new project.
4. Wait for the indicator to turn **Online**, then click **Launch Node Leaf**.

---

## 🔎 Project Library & Info Panel

Open **Project Library** and type in the search field to filter by project name or folder path. The project inspector starts **closed**. Click anywhere on a project row (including the **i** icon) to slide its inspector in from the right; click the same row again to slide it closed. You can also use the **Show inspector** toggle in the library header. The Root, Documents, and Server buttons continue to perform their own actions. The icon stays the same, with blue indicating active and muted gray indicating inactive. On wide windows, the list resizes alongside the panel; on narrow windows, the inspector slides over the list.

The panel shows:

- **Redleaf tags** and their document counts, read from the local `knowledge_base.db` SQLite database without starting the Flask server. Python 3 must be available, either on the system path or through the Conda environment configured in Hub Settings.
- **RLink locations** from `documents/*.rlink`. Green indicates an available directory, and orange indicates a missing or unreadable target. Use **Relocate** to select the new directory for a missing link. This rewrites only that `.rlink` file; it does not move any external documents.
- **Project notes** in the editable notes field, automatically saved after typing stops. Notes live in `.redleaf_hub_notes.txt` under the selected project's root and move with that project.

The tag list can be refreshed using the refresh button at the top of the info panel. Reading tags and RLinks requires no network connection.

---

## 📄 License

MIT License

Copyright (c) 2026 Nathaniel Westveer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
