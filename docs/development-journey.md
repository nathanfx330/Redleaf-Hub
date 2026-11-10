<!-- docs/development-journey.md -->

# Redleaf Hub: Development Overview and Update Record

**Record through November 10, 2026**

This is the development history of Redleaf Hub, not its setup manual. Part I explains the problem the application was built to solve and how its architecture and interface evolved. Part II records the first November 8 and 9 integration milestones, including the alternatives rejected and problems found in testing. Part III continues through November 10, covering vault reproducibility, paired CI checks and the coordinated Gold merges.

For current installation and daily use, see the [root README](../README.md). For the corresponding player history, see [MLT Player's development journey](https://github.com/nathanfx330/MLT-Player/blob/main/docs/development-journey.md). The linked pull requests are the dated implementation record. A development history describes past decisions; source code and current reference documentation remain the authority for behavior.

---

# Part I. Development overview

## 1. The original problem: many Redleaf projects, one starting point

A Redleaf research project has a real folder and a Python/Flask backend. Node Leaf is a separate visual application. Before a central launcher, starting work involved remembering where each project lived, managing Python or Conda environments, opening the correct server, and then opening the visual client.

Redleaf Hub was built as a **desktop project launcher and coordinator**, not as another database or as a replacement for either application. Its job is to make each Redleaf project visible, launch its backend, and hand users into the applications that work with its contents.

Three identities matter:

| Layer | Owns | Does not own |
| --- | --- | --- |
| Redleaf project folder and backend | The research database, document relationships, and authentication | Hub's window layout |
| Redleaf Hub | Project discovery, local orchestration, launcher configuration, project inspection | A copy of the Redleaf database |
| Node Leaf or MLT Player | Their respective visual or media workflows | Redleaf's canonical database identity |

This division is important. A launcher should not silently move documents, mutate an archive, or invent a new database merely because a user opens another application.

## 2. First functional foundation: setup, templates, and process control

The original Hub workflow began with a **home screen** for creating a project, opening the library, and visiting Settings. Settings recorded a master project directory, the Node Leaf executable, optional Conda environment, and Redleaf template Git URL.

The application could fetch a reusable Redleaf template to a hidden local cache, then create another project by copying that template. Project discovery scanned immediate children of the configured root for Redleaf project folders rather than requiring a separate cloud registry. The result was an offline-first library of independent Redleaf installations.

A project server is started as a separate native terminal process. Hub polls the local backend port and reports its reachability. It can then launch Node Leaf without turning the Flutter application into a server or embedding the backend in Hub.

**Original design boundary:** the port check confirms that something is listening at `localhost:5000`. It does not prove that the server corresponds to the selected project's database. That distinction became important when MLT Player was added.

Relevant implementation: [`lib/state/hub_state.dart`](../lib/state/hub_state.dart), [`lib/ui/setup_screen.dart`](../lib/ui/setup_screen.dart), and [`lib/ui/home_screen.dart`](../lib/ui/home_screen.dart).

## 3. The project library became the daily workspace

A list of project folders was useful, but insufficient once the number of archives grew. The library became searchable by folder name or path and gained a slide-in project inspector. This made inspection possible without starting Flask or leaving Hub.

The inspector can read existing document tags and counts directly from `knowledge_base.db` using Python's SQLite support. It also examines `documents/*.rlink` references, reports whether external targets are available, and offers an explicit relocation action for broken links. Relocation changes only the selected `.rlink` target, not the external document collection.

Per-project notes are saved in `.redleaf_hub_notes.txt` inside the project directory, so they travel with the archive instead of being tied to Hub's global configuration.

The interface was refined around the existing dark graphite palette, alternating candy-striped rows, restrained Redleaf red accents, a searchable top toolbar, and an inspector that begins closed. The home screen retained responsibility for project creation; the library remained a place to find, inspect, and open existing projects.

This milestone was merged in [PR #1, November 8, 2026](https://github.com/nathanfx330/Redleaf-Hub/pull/1). Relevant source: [`lib/state/project_inspector.dart`](../lib/state/project_inspector.dart) and [`lib/ui/project_info_panel.dart`](../lib/ui/project_info_panel.dart).

## 4. Architecture that emerged

The modern desktop workflow can be summarized as:

```text
Hub home / Settings
    |
    +-- Configure template, project root and app executables
    |
    +-- Create a Redleaf project from a cached template
    |
    +-- Open searchable Project Library
           |
           +-- Read project tags, notes and .rlink targets offline
           +-- Launch Redleaf backend in its own terminal
           +-- Observe local server reachability
           +-- Launch Node Leaf or MLT Player
```

`HubState` coordinates configuration, discovered projects, active project and server status. The project inspector owns offline inspection; UI widgets render the library and details. The other applications remain separate processes.

The development lesson was that a **central entry point** need not become a central owner of everybody else's data.

---

# Part II. Update chapter: November 8 and 9, 2026

## Chapter 1. From project launcher to connected desktop workspace

### 1. Library and inspector consolidation, November 8

[PR #1](https://github.com/nathanfx330/Redleaf-Hub/pull/1) established the daily-use library: fast search, responsive inspector, read-only SQLite tag inspection, `.rlink` detection and repair, portable notes, and associated widget and filesystem tests.

The important choice was to **inspect existing Redleaf state**, not to invent a Hub-side metadata store or require a running Redleaf service for every project detail. A user can inspect an archive that is not currently running.

### 2. Adding MLT Player as a second client, November 9

[PR #2](https://github.com/nathanfx330/Redleaf-Hub/pull/2) extended the same launch concept to MLT Player. Hub Settings gained an optional MLT Player executable path, while Node Leaf and existing first-run requirements stayed intact.

Hub launches the selected project with two nonsecret arguments:

```text
--redleaf-hub-project-path "/path/to/Redleaf project"
--redleaf-hub-server-url http://127.0.0.1:5000
```

Hub does **not** pass a password, login cookie or authenticated session. MLT Player reads the selected project's SQLite `instance_id`, checks its own project registry and saved snapshot, and decides whether to open a cached workspace, prompt for authentication and import, or require explicit restoration of a trashed project.

That division prevents a launcher from silently creating duplicate MLT projects or assuming that a reachable port is the correct Redleaf instance. The authenticated server identity is checked inside MLT Player before import.

The companion implementation is [MLT Player PR #12](https://github.com/nathanfx330/MLT-Player/pull/12).

### 3. Removing the repeated password step

A usability problem became clear: Redleaf could already be running, yet MLT Player still needed a fresh login for an unsynced project. Having the user open Player and type credentials each time defeated the purpose of launching directly from Hub.

The first shared-login design used the Linux Secret Service through `secret-tool`. That imposed a utility or keyring-service dependency and failed the intended self-contained desktop experience. The approach was replaced rather than making a system package part of the workflow.

The approved implementation is a **shared, app-managed encrypted vault**, with [`lib/services/redleaf_shared_credential_vault.dart`](../lib/services/redleaf_shared_credential_vault.dart) implemented compatibly in both apps:

- Credentials are saved explicitly per initialized Redleaf database `instance_id`, with an approved server origin.
- Each secret record uses bundled AES-256-GCM authenticated encryption and a fresh nonce.
- The shared Linux directory is `$XDG_DATA_HOME/redleaf-hub-mlt-auth/v2`, falling back to `$HOME/.local/share/redleaf-hub-mlt-auth/v2`.
- Vault directories use `0700` permissions and key and encrypted record files use `0600` permissions.
- The password and encryption key never travel in Hub's launch arguments. The browser password manager is a separate system and is not imported.

The project-row **Credentials** dialog can save, replace and remove a login. MLT Player reads the same vault, authenticates against Redleaf, and still verifies the server's database identity. Invalid or unavailable credentials fall back to manual sign-in.

**Security tradeoff:** Unattended login requires both programs to read the local encryption key. An attacker already executing software with the user's Linux privileges could obtain that key and the encrypted records. This solution avoids plaintext project settings and extra installed services; it is **not** equivalent to a separately unlocked operating-system or hardware-backed vault.

The credential dialog and identity reader live in [`lib/ui/redleaf_credentials_dialog.dart`](../lib/ui/redleaf_credentials_dialog.dart) and [`lib/services/redleaf_project_identity_service.dart`](../lib/services/redleaf_project_identity_service.dart).

### 4. One launcher instead of stacked notifications

The first MLT integration added a second 82-pixel launcher banner beneath the Node Leaf banner. Both were functional, but the duplicate server indicators consumed vertical space and made one live Redleaf server look like two separate statuses.

[PR #3, November 9](https://github.com/nathanfx330/Redleaf-Hub/pull/3) replaced them with **one 82-pixel online bar** containing the server indicator, project identity, and both launch buttons. Narrow windows show shorter button labels; unconfigured MLT Player still leads to Settings.

This was a consolidation, not a redesign of the approved home screen, project inspector, or colors. Both launch actions remained independent.

### 5. Verification, failures and final merges

The work was developed on feature branches, tested in CI and the Linux GUI, and merged only after approval.

| Milestone | Merged PR | Verified record |
| --- | --- | --- |
| Searchable library and offline inspector | [#1](https://github.com/nathanfx330/Redleaf-Hub/pull/1) | Inspector and file/SQLite test coverage |
| MLT Player launch and encrypted credentials | [#2](https://github.com/nathanfx330/Redleaf-Hub/pull/2) | Flutter analysis and vault tests, with corresponding MLT PR #12 |
| Unified launcher and compact layout | [#3](https://github.com/nathanfx330/Redleaf-Hub/pull/3) | CI run #55 passed before merge |

A narrow-window launcher test initially failed because mocked preferences were initialized after the Hub state began loading. Correcting the test setup fixed that race. It was not a reason to change the approved launcher UI.

Final merged Hub commits include `9521452` for the launch and vault milestone and `5620159` for the consolidated launcher. Both changes were merged into `main` on November 9, 2026.

### 6. What this chapter establishes

Redleaf Hub now serves as a consistent **entry point for multiple Redleaf-aware applications**. It owns the project picker, offline inspection, process launching and optional saved credentials. Redleaf still owns the database, Node Leaf still owns its visual workflows, and MLT Player owns its project onboarding, media catalog and playback.

The remaining boundary worth protecting is the distinction between **server reachability and server identity**. Port 5000 alone is not authorization; any client that acts on Redleaf data must independently verify the intended database instance.

# Part III. Late November 9 through November 10, 2026

## Chapter 2. Vault hardening, coordinated parity checks, and Gold

The prior chapter stops at the first Hub launch and unified-bar checkpoint. This continuation records later review and CI work, with dates spanning November 9 US Eastern time and the early hours of November 10 UTC. It distinguishes changes made in **Redleaf Hub** from subsequent browser and Player fixes made **only in MLT Player**.

### 1. The shared vault needs a portable and reproducible contract

Hub and MLT Player intentionally ship compatible copies of `lib/services/redleaf_shared_credential_vault.dart`. A review of the initial implementation found that an architecture-specific numeric `O_NOFOLLOW` flag was not a portable way to express the file-creation constraint. The fix kept portable exclusive creation (`O_CREAT | O_EXCL`) without embedding a platform-specific constant in the code.

[Hub PR #5](https://github.com/nathanfx330/Redleaf-Hub/pull/5) and [MLT PR #15](https://github.com/nathanfx330/MLT-Player/pull/15) also added a committed dependency lock and CI enforcement through `flutter pub get --enforce-lockfile` followed by a clean-lockfile check. Flutter CI was pinned to a known stable version, and Hub removed merged feature branches from its push triggers. The paired change added an automated byte-for-byte vault parity check. Its purpose was to prevent the two desktop applications from silently diverging on shared credential handling.

These changes did not alter Redleaf's database, the encrypted vault record format, or the approved login flow. They hardened portability and made dependency and source verification reproducible.

### 2. Two repositories cannot be merged atomically

The initial strict parity check had a practical merge-order problem. Even when the two feature branches contained identical vault source, merging either branch first could cause its `main` CI to fail before the companion repository caught up.

[Hub PR #6](https://github.com/nathanfx330/Redleaf-Hub/pull/6), paired with [MLT PR #16](https://github.com/nathanfx330/MLT-Player/pull/16), established separate policies for three events:

| Event | Vault parity behavior |
| --- | --- |
| Pull request | **Strict:** compares the vault with the matching branch in the other repository, falling back to `main` if the branch is absent; drift fails the check. |
| Push to `main` | **Advisory:** reports mismatches as warnings while an authorized two-repository merge is in progress. |
| Scheduled job | **Strict:** audits both published `main` branches after the merge window. |

Hub's strict daily audit is scheduled for **09:17 UTC**. MLT Player's is scheduled for **09:43 UTC**. These scheduled jobs are lightweight checks of the cross-repository vault implementation, separate from regular Flutter and native Player tests.

The shared `tool/check_shared_vault.sh` resolves the counterpart branch head with `git ls-remote` and fetches its file through an immutable commit SHA. The earlier approach retrieved `raw.githubusercontent.com` content through a mutable branch URL and could encounter stale branch-cache bytes. After the paired merge, both repositories contained byte-identical scripts as well as byte-identical vault implementations.

The script compares the vault file, not its own script source. Strict failures rely on `set -e` propagation from `report_issue`; no explicit `GIT_TERMINAL_PROMPT=0` was added. GitHub may disable scheduled workflows on inactive public repositories after an extended idle period. These maintenance notes were recorded as nonblocking for this Gold checkpoint.

### 3. The separate MLT Player PROJECT browser and handoff work

After the initial integration, MLT Player improved Redleaf browsing without a corresponding Hub UI change. The distinction matters: Hub still discovers projects, manages the launcher, and passes nonsecret project identity hints. MLT Player independently authenticates and manages its own Redleaf workspace, thumbnails and playback.

The late-November-9 MLT changes included:

- [MLT PR #17](https://github.com/nathanfx330/MLT-Player/pull/17) mounted the existing Redleaf linked-video browser inside **PROJECT**, beside the Project **OVERVIEW**.
- [MLT PR #18](https://github.com/nathanfx330/MLT-Player/pull/18) stopped reopening that gallery from replaying an old Settings import, and required a process-wide drain of outstanding native thumbnail decoding before Player could open.
- [MLT PR #19](https://github.com/nathanfx330/MLT-Player/pull/19) renamed the PROJECT destination to **BROWSE** and added the non-modal **Finishing thumbnail…** indication during slow native drain waits. The internal thumbnail/table toggle remains separate from the PROJECT navigation label.
- [MLT PR #20](https://github.com/nathanfx330/MLT-Player/pull/20) invalidated stale Player requests when workspace or Project navigation occurs, including those awaiting a transcript or thumbnail operation.
- [MLT PR #21](https://github.com/nathanfx330/MLT-Player/pull/21) restored Redleaf thumbnail browsing after a cancelled handoff, without prematurely restarting decoding while newer operations are pending.

These are media-lifecycle responsibilities of **MLT Player**, not Redleaf Hub. They do not change Hub's home screen, approved library design, process-launch contract or credential-vault semantics. The remaining narrow Player shell acknowledgement edge is tracked separately as [MLT Issue #22](https://github.com/nathanfx330/MLT-Player/issues/22), with low priority.

For implementation and regression details, see the corresponding [MLT Player development journey](https://github.com/nathanfx330/MLT-Player/blob/main/docs/development-journey.md) and its current Redleaf workspace reference.

### 4. Validation and merged Gold checkpoints

| Hub milestone | Merged PR | Evidence or resulting contract |
| --- | --- | --- |
| Searchable Project Library and offline inspector | [#1](https://github.com/nathanfx330/Redleaf-Hub/pull/1) | Offline metadata, linked-folder inspection and notes remain independent of a running backend. |
| Direct MLT Player launch and shared vault | [#2](https://github.com/nathanfx330/Redleaf-Hub/pull/2) | Nonsecret launch arguments, separate client authentication, explicit credential storage. |
| One-row launcher | [#3](https://github.com/nathanfx330/Redleaf-Hub/pull/3) | Unified server state and distinct app actions, without redesigning the home screen. |
| Vault portability and dependency reproducibility | [#5](https://github.com/nathanfx330/Redleaf-Hub/pull/5) | Portable exclusive file creation, locked Flutter dependencies, cross-repository parity checks. |
| Merge-safe vault checks and daily strict audit | [#6](https://github.com/nathanfx330/Redleaf-Hub/pull/6) | Strict PR and nightly parity, advisory `main` pushes, SHA-pinned counterpart fetch. |

Hub PR #5 was merged as `46fd392`. The coordinated November 10 vault-check merge concluded with **Hub PR #6** at `3e85e88` and **MLT PR #16** at `bb2bb7e`. CI for both PRs passed before merging. The post-merge audit of the actual `main` files confirmed that the two vault implementations and the two parity checkers were byte-identical.

The remaining Player shell acknowledgement issue was deliberately deferred, rather than patching a single cancellation path and leaving the other paths unaddressed.

---

## Continuing this history

Add future changes as a new dated chapter, with the observed problem, implementation decision, alternatives discarded, test evidence, and merged pull request. Do not overwrite earlier decisions merely because a newer implementation supersedes them.

For current behavior, consult the [README](../README.md) and the source files linked above. For the corresponding MLT Player integration and its media-side constraints, see [MLT Player's development journey](https://github.com/nathanfx330/MLT-Player/blob/main/docs/development-journey.md).
