# Redleaf Hub

**Redleaf Hub** is the central desktop launcher and project manager for the Redleaf Knowledge Graph ecosystem. Built in Flutter, it acts as the grand orchestrator between your [Redleaf](https://github.com/nathanfx330/redleaf) Python/Flask backend instances and your [Node Leaf](https://github.com/nathanfx330/node-leaf) visual RAG canvas.

Instead of manually managing terminal windows, Python environments, and scattered folders, Redleaf Hub gives you a sleek, dark-themed UI to create, launch, and manage isolated knowledge bases from a single place.

**Development history:** [Development Overview and November 2026 Update](docs/development-journey.md) traces the Project Library, offline inspector, MLT Player launch, the shared credential vault, and coordinated November 10 Gold and vault-parity CI changes.

---

## ✨ Key Features

* **Project Library:** A searchable, minimalist list of all your Redleaf knowledge bases, with a project information sidebar.
* **Offline Project Inspector:** Reads document tags directly from each project's `knowledge_base.db` and displays external `.rlink` folder targets with missing-directory warnings and relocation controls.
* **Project Notes:** Automatically saves notes separately for each project in `.redleaf_hub_notes.txt` at that project's root.
* **Offline Project Generation:** Caches a master template of the Redleaf repository locally. Creating a new project clones it directly from your hard drive, completely internet-independent.
* **Smart Server Detection:** Click "Pop Terminal Server" to spawn a native OS terminal running the backend. The Hub silently polls the server and illuminates a green "Online" indicator when the database is unlocked and ready.
* **Node Leaf Integration:** Once a server is live, a launcher bar slides up allowing you to instantly boot your compiled Node Leaf visual canvas.
* **MLT Player Integration:** The same server-online library footer offers a second launcher for MLT Player. It hands off the selected Redleaf project folder and server URL, not any credentials. MLT Player opens a verified cached workspace immediately or provides its own sign-in, naming, and import onboarding.
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
3. **MLT Player Executable (Optional):** Choose the compiled MLT Player desktop executable. On Linux, this is typically `.../build/linux/x64/release/bundle/mlt_player`. The initial Hub setup still only requires the master project folder and Node Leaf path.
3. **Conda Environment (Optional):** If your Redleaf Python dependencies live inside a Conda environment, type the name here (e.g., `redleaf-env`).
4. **Template Git URL:** The default Redleaf repository URL. Change this if you maintain a private fork.

**The Workflow:**
1. Click **Download Required Master Template** to pull the engine down to your hidden cache.
2. Click **Create New Redleaf Repo** to spin up an isolated, offline instance.
3. Click **Pop Terminal Server** on your new project.
4. Wait for the indicator to turn **Online**, then click **Launch Node Leaf**.

---

## Built-in encrypted Redleaf password vault

Every Redleaf project in Hub's Project Library has a **Credentials** action.
Save, replace or remove a Redleaf username and password for that project's
canonical database instance ID. Hub reads the identity from
`knowledge_base.db` read-only. The database must already be initialized.

There is **no external keyring utility, keyring daemon or operating-system
package to install**. Both apps bundle the same Dart vault implementation.
The vault encrypts each credential record with **AES-256-GCM** using a random
key and unique nonce. On Linux it stores the encrypted records in a private
directory under `$XDG_DATA_HOME/redleaf-hub-mlt-auth/v2`, defaulting to
`$HOME/.local/share/redleaf-hub-mlt-auth/v2`. Directory permissions are
`0700` and key and encrypted record permissions are `0600`.

The two applications share the same files. The launch arguments still contain
only the selected project folder and approved server URL, never passwords,
session cookies or login tokens. Each secret is tied to its Redleaf instance
ID and approved server origin `http://127.0.0.1:5000`. If the origin changes
or authentication fails, MLT Player requires manual login. Cached projects
still open without a network connection or keyring.

**Security limitation:** To support automatic login without asking for a
master password, the encryption key is stored under the same Linux account.
Encryption and file permissions protect against accidental exposure and
other Linux users, but an attacker already running code with your user
permissions could read both the key and the encrypted records. This is not
equivalent to a hardware-backed or separately unlocked password manager.

The vault is independent of browser-stored passwords. Save the credential
once using Hub's project Credentials button. No OS package installation is
necessary. The cryptography implementation is compiled into the Flutter apps.

---

## 🎬 MLT Player launch and onboarding

When Redleaf Hub shows the green **Online** status for an active project, the
Project Library displays **one shared 82-pixel launcher bar** with the selected
Redleaf project, **Launch Node Leaf**, and **Launch MLT Player** side by side.
This replaces the two stacked online banners without changing either launch
action. If the MLT Player executable is not configured, its button opens
**Settings & Paths** instead. Hub launches each app as a detached desktop
process. On narrow windows the same actions use compact labels.

The handoff arguments are:

```text
--redleaf-hub-project-path "/path/to/Redleaf project" --redleaf-hub-server-url http://127.0.0.1:5000
```

Hub passes no username, password, session, or auth token in its launch
command. MLT Player can retrieve an explicitly saved Redleaf login from the
shared encrypted local vault. MLT Player reads the
selected folder's initialized `knowledge_base.db` in read-only mode to
identify the database instance, then checks **its own** saved project registry
and a valid synced transcript snapshot.

- **Saved and synced:** open the exact project and its cached SRT/catalog
  snapshot immediately, even without a new authentication session.
- **Unsynced or never imported:** open MLT Player's onboarding dialog. Enter
  its local display name and Redleaf server URL, username, and password. MLT
  Player authenticates with Redleaf, verifies the server returned the same
  instance ID as the selected local database, and imports the catalog.
- **In MLT Player Trash:** require explicit restoration. A saved cached
  snapshot can be restored without signing in; an unsynced project needs
  sign-in and import.

The Redleaf database itself and its media files are not moved, renamed, or
modified. Existing offline MLT Player launches via `--redleaf-project-path`
are unchanged; the new Hub-specific flag is deliberately distinct.

**Current limitation:** Hub's server-online indicator tests whether the
local port 5000 is reachable, not which Redleaf instance is responding.
MLT Player therefore verifies the authenticated instance ID before importing
anything. If it reports a mismatch, stop the wrong Redleaf server and launch
the selected project from Hub.

---

## 🔎 Project Library & Info Panel

The **Home screen stays unchanged**: it is still the starting point for **Create New Redleaf Repo**, **Open Project Library**, and **Settings & Paths**. In the Project Library, the **Redleaf Hub** heading and search box share the top toolbar (the search box wraps below the heading on narrow windows). There is no Add Project button in the library. Rows keep the existing alternating dark candy stripes and red folder icons, with a muted gray selection and no blue selection stroke.

The inspector starts **closed**. Click anywhere on a project row (including the **i** icon) to slide its inspector in from the right; click the same row again to slide it closed. You can also use the **Show inspector** toggle in the library header. The Root, Documents, and Server buttons continue to perform their own actions. The information icon is red when active and muted gray when inactive. On wide windows, the list resizes alongside the panel; on narrow windows, the inspector slides over the list. The Node Leaf server footer uses the same dark graphite and restrained Redleaf-red design.

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
