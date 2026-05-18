# devmachine

Ansible-Setup für eine RHEL-9.6-Entwicklermaschine mit:

- VS Code (Linux RPM aus `roles/ide_vscode/files/`)
- VS Code Plugins (alle `*.vsix` aus `roles/ide_vscode/files/plugins/` werden auto-discovered)
- IntelliJ IDEA (Linux tar.gz aus `roles/ide_intellij/files/`, Plugins als `.zip`/`.jar` aus `roles/ide_intellij/files/plugins/`)
- Google Chrome (RPM aus `roles/chrome/files/`)
- XFCE-Desktop mit xrdp (RDP-Zugriff für `vm_owner[0]`)
- Podman (rootless für `vm_owner[0]`)
- pyenv + aktuelle Python-Version via Nexus für `vm_owner[0]`
- nvm + aktuelle Node-LTS via Nexus für `vm_owner[0]`
- OpenJDK 21 + 17 (`devel`-Pakete aus RHEL AppStream), 21 als System-Default
- Apache Maven via Nexus (systemweit) + `~vm_owner/.m2/settings.xml` mit Proxy- und Mirror-Config
- Git-Vorbereitung für `vm_owner[0]` (known_hosts, Identity, optionales Auto-Klonen unter `/mnt/data`)
- Java-Entwicklungspaketen über ein Nexus-Repository
- Nexus-Konfiguration für `npm` und `pyenv`/`pip`

## Voraussetzungen

- Steuerrechner mit Ansible
- Zielsystem(e): RHEL 9.6
- Die Quell-Pakete liegen in den Rollen-Ordnern `roles/ide_vscode/files/` (RPM, VSIX-Plugins
  unter `files/plugins/`),
  `roles/ide_intellij/files/` (tar.gz, Plugins unter `files/plugins/`) und `roles/app_chrome/files/` (Chrome-RPM) — werden manuell
  dort hineinkopiert.
- EPEL-Pakete müssen via dnf installierbar sein. Die Rollen `xrdp` (XFCE + xrdp) und
  `app_cli` (mosh + ripgrep + fd-find) ziehen aus EPEL. Wenn dein Nexus EPEL nicht spiegelt,
  vorher den EPEL-Mirror als zusätzliches `yum_repository` einrichten (analog zum
  bestehenden `nexus-rhel9-baseos`).
- `vm_owner[0]` muss als Linux-User existieren und für xrdp-Login ein **Linux-Passwort**
  gesetzt haben. Das Playbook legt den User nicht an und setzt kein Passwort.
- Nur `ansible-core` nötig — keine zusätzlichen Galaxy-Collections.

## Linux-Pakete per PowerShell herunterladen

```powershell
pwsh -File ./tools/download-linux-ide-packages.ps1 -OutputDirectory ./downloads
```

Optional: direkt per SCP auf die Zielmaschine hochladen (initialer Login z. B. `root` mit Passwort):

```powershell
pwsh -File ./tools/download-linux-ide-packages.ps1 `
  -OutputDirectory ./downloads `
  -UploadToTarget `
  -ScpTargetHost rhel96.example.local `
  -ScpUsername root `
  -ScpTargetPath /opt/devmachine/packages
```

Optional (nur beim ersten Kontakt): `-ScpAcceptNewHostKey` setzen, damit neue Host-Keys automatisch akzeptiert werden.

Mit automatischer Passwortübergabe (wenn `sshpass` installiert ist):

```powershell
$pw = Read-Host "Root password" -AsSecureString
pwsh -File ./tools/download-linux-ide-packages.ps1 `
  -OutputDirectory ./downloads `
  -UploadToTarget `
  -ScpTargetHost rhel96.example.local `
  -ScpUsername root `
  -ScpPassword $pw
```

Hinweis: Für Produktion nach der Initialphase bevorzugt per SSH-Key und dediziertem User statt `root`+Passwort arbeiten.
Wenn `-ScpPassword` genutzt wird, nutzt `sshpass` intern die Umgebungsvariable `SSHPASS` während des Uploads.

Danach die Dateien in die jeweiligen Rollen-Ordner kopieren:

```bash
cp ./downloads/code-1.120.0-1778619100.el8.x86_64.rpm ./roles/ide_vscode/files/
cp ./downloads/*.vsix                                 ./roles/ide_vscode/files/plugins/
cp ./downloads/idea-2026.1.2.tar.gz                   ./roles/ide_intellij/files/
cp ./downloads/intellij-plugins/*.zip                 ./roles/ide_intellij/files/plugins/
```

Die Rollen `ide_vscode` und `ide_intellij` kopieren die Dateien dann auf den Zielhost und
installieren VS Code (systemweit, plus VSIX-Extensions für `vm_owner[0]`) bzw. IntelliJ
(systemweit unter `/opt/jetbrains/idea-*` mit Symlink `/usr/local/bin/idea`).

## Konfiguration

Standardwerte stehen in den jeweiligen `roles/<rolle>/defaults/main.yml` und können via `-e`
überschrieben werden, z. B.:

`ide`-Rolle (Nexus, Java, ansible-Login, Workspaces, npm/pip/pyenv, sudo):

- `devmachine_nexus_fqdn`
- `devmachine_proxy_fqdn`
- `devmachine_nexus_base_url`
- `devmachine_dnf_repo_url`
- `devmachine_dnf_gpgcheck`
- `devmachine_dnf_gpgkey`
- `devmachine_npm_registry_url`
- `devmachine_pyenv_mirror_url`
- `devmachine_pip_index_url`
- `devmachine_target_users`
- `devmachine_sudo_nopasswd`
- `devmachine_workspace_setup_enabled`
- `devmachine_workspace_root`
- `devmachine_workspace_link_name`
- `devmachine_shared_workspace_enabled`
- `devmachine_shared_workspace_path`
- `devmachine_shared_workspace_owner`
- `devmachine_shared_workspace_group`
- `devmachine_general_user_enabled`
- `devmachine_general_user`
- `devmachine_general_user_shell`
- `devmachine_ansible_login_user`
- `devmachine_ansible_login_ssh_key_path`
- `devmachine_ansible_login_ssh_key_passphrase`
- `devmachine_ansible_login_ssh_key_vault_file`
- `devmachine_ansible_login_ssh_key_vault_password_file`

`ide_vscode`-Rolle:

- `ide_vscode_rpm` — Dateiname des VS Code RPMs in `files/`.
- `ide_vscode_sha256` — optionale SHA256-Prüfung des RPMs.
- `ide_vscode_package_dir` — Zielverzeichnis auf dem Host (Default `/opt/devmachine/packages`).
- `ide_vscode_plugins_subdir` — Unterverzeichnis unter `files/` für VSIX-Plugins (Default `plugins`).
  Alle `*.vsix` darin werden automatisch erkannt, auf den Host kopiert und für `vm_owner[0]`
  installiert. Drop-File → nächster Lauf zieht es hoch.

`ide_intellij`-Rolle:

- `ide_intellij_archive` — Dateiname des IntelliJ-Tarballs in `files/`.
- `ide_intellij_sha256` — optionale SHA256-Prüfung des Tarballs.
- `ide_intellij_install_dir` — Basis für die Extraktion (Default `/opt/jetbrains`).
- `ide_intellij_symlink` — Symlink zum `idea`-Launcher.
- `ide_intellij_package_dir` — Staging-Ort des Tarballs auf dem Host.
- `ide_intellij_plugins_subdir` — Unterverzeichnis unter `files/` für Plugins (Default `plugins`).
  Alle `*.zip` darin werden in `<INSTALL>/plugins/` entpackt, alle `*.jar` direkt dort abgelegt.
  Drop-File → nächster Lauf zieht es hoch. **Achtung:** bei IntelliJ-Update wird das alte
  `idea-*`-Dir gewipt, Plugins werden im selben Lauf neu installiert.

`app_chrome`-Rolle:

- `app_chrome_rpm`
- `app_chrome_sha256`
- `app_chrome_package_dir`

`app_git`-Rolle:

- `app_git_target_root` — Pflichtwurzel für alle Repo-Targets (Default `/mnt/data`).
- `app_git_user_key_filename` — Name des erwarteten SSH-Keys unter `~vm_owner/.ssh/` (Default `id_ed25519`).
- `app_git_user_name` / `app_git_user_email` — Git-Identity für `vm_owner[0]` (`git config --global`).
  Wenn leer, werden die Tasks übersprungen.
- `app_git_global_config` — Dict von zusätzlichen `git config --global`-Einträgen. Defaults:
  `init.defaultBranch=main`, `pull.rebase=false`, `fetch.prune=true`, `core.editor=vim`,
  `credential.helper=cache --timeout=14400`.
- `app_git_hosts` — Liste der akzeptierten Git-Hosts als `{name, fingerprints}`-Dicts.
  Die Rolle holt zur Laufzeit per `ssh-keyscan` die Host-Keys und nimmt nur die in `known_hosts`
  auf, deren SHA256-Fingerprint in `fingerprints` steht. Bricht ab, wenn kein Key matcht.
- `app_git_repos` — Liste der zu klonenden Repos. Jeder Eintrag muss `repo` und `target` setzen,
  `target` muss unter `app_git_target_root` liegen. Beispiel:

  ```yaml
  app_git_repos:
    - repo: git@github.com:org/service-a.git
      target: /mnt/data/workspaces/huhu/git/service-a
    - repo: git@github.com:org/service-b.git
      target: /mnt/data/workspaces/huhu/git/service-b
  ```

`app_podman`-Rolle:

- `app_podman_packages`
- `app_podman_docker_compat`
- `app_podman_subuid_start`
- `app_podman_subuid_count`
- `app_podman_enable_lingering`
- `app_podman_verify_rootless`
- `app_podman_storage_base` — Wurzel für Container-Storage (Default `/mnt/data/podman`).
  Root nutzt `<base>/root/storage`, `vm_owner[0]` nutzt `<base>/<user>/storage`.
- `app_podman_storage_driver` / `app_podman_storage_mount_program` — Overlay-Treiber-Konfiguration.
- `app_podman_harbor_host` — Hostname der Harbor-Instanz (z. B. `harbor.example.com`).
  Wenn gesetzt, wird der Host in `unqualified-search-registries` aufgenommen und ein
  `[[registry]]`-Block in `/etc/containers/registries.conf` erzeugt.
- `app_podman_unqualified_search_registries` — zusätzliche Suchregistries (werden hinter Harbor
  angehängt).
- `app_podman_auth_json_vault_file` — Pfad zur Ansible-Vault-Datei, die `app_podman_auth_json`
  enthält. Wenn vorhanden, wird die `auth.json` für root **und** `vm_owner[0]` ausgerollt.

`app_pyenv`-Rolle:

- `app_pyenv_version` — pyenv-Tag (Default `2.6.31`).
- `app_pyenv_archive_url` — Nexus-Pfad zum pyenv-Tarball (Default leitet sich aus `app_pyenv_version` ab).
- `app_pyenv_python_version` — zu installierende Python-Version (Default `3.14.5`). Leer = automatische
  Auflösung der höchsten 3.x.y aus `pyenv install --list`.
- `app_pyenv_python_build_mirror_url` — Python-Source-Tarball-Mirror auf Nexus.
- `app_pyenv_proxy_url` — HTTP/HTTPS-Proxy für den `pyenv install`-Lauf (Default = `devmachine_proxy_url`).
- `app_pyenv_install_subdir` — Verzeichnisname unter `~vm_owner` (Default `.pyenv`).
- `app_pyenv_profile_path` — Pfad der erzeugten `/etc/profile.d/`-Datei.

`app_java`-Rolle:

- `app_java_packages` — Liste der zu installierenden OpenJDK-Pakete (Default
  `java-21-openjdk-devel` + `java-17-openjdk-devel`, beide aus RHEL 9.6 AppStream).
- `app_java_default_version` — Major-Version, die per `alternatives --set java/javac`
  als System-Default gesetzt wird (Default `21`).
- `app_java_profile_path` — `/etc/profile.d/`-Datei, die `JAVA_HOME` und `PATH` setzt.

`app_maven`-Rolle:

- `app_maven_version` — Maven-Version (Default `3.9.16`).
- `app_maven_archive_url` — Nexus-Pfad zum Maven-Tarball (Default leitet sich aus `app_maven_version` ab).
- `app_maven_install_base` — Basis für die Extraktion (Default `/opt`; resultiert in `/opt/apache-maven-X.Y.Z`).
- `app_maven_symlink` — Symlink zum `mvn`-Launcher (Default `/usr/local/bin/mvn`).
- `app_maven_profile_path` — Pfad zum Profile-Snippet (setzt `M2_HOME`, `MAVEN_HOME`, `PATH`).
- `app_maven_nexus_repository` — URL des Maven-Repositories in Nexus (`<mirror>` in `settings.xml`).
- `app_maven_proxy_host` / `app_maven_proxy_port` — Proxy-Daten für die `<proxies>`-Sektion.
- `app_maven_non_proxy_hosts` — Pipe-getrennte Liste der vom Proxy ausgenommenen Hosts.

`app_nvm`-Rolle:

- `app_nvm_version` — nvm-Tag (Default `0.40.4`).
- `app_nvm_archive_url` — Nexus-Pfad zum nvm-Tarball (Default leitet sich aus `app_nvm_version` ab).
- `app_nvm_node_version` — zu installierende Node-Version (Default `v24.15.0`). `--lts` bewirkt
  „latest LTS" via nvm-Resolver.
- `app_nvm_set_default` — Default-Alias über `nvm alias default` setzen.
- `app_nvm_nodejs_mirror_url` — Node-Tarball-Mirror auf Nexus.
- `app_nvm_proxy_url` — HTTP/HTTPS-Proxy für den `nvm install`-Lauf.
- `app_nvm_install_subdir`, `app_nvm_profile_path` — Verzeichnis und Profile-Snippet.

`common_sysctl`-Rolle:

- `common_sysctl_inotify_max_user_watches` (Default `1048576`) — IDE-Indexing in großen Repos.
- `common_sysctl_inotify_max_user_instances` (Default `8192`).
- `common_sysctl_vm_max_map_count` (Default `262144`) — IntelliJ/Elasticsearch/Container-Workloads.
- `common_sysctl_fs_file_max` (Default `2097152`).

`common_locale`-Rolle:

- `common_locale_timezone` (Default `Europe/Berlin`) — via `timedatectl`.
- `common_locale_lang` (Default `de_DE.UTF-8`) — via `localectl`, inkl. `glibc-langpack-<lang>`.
- `common_locale_keymap` (Default `de`) — Konsolen-Keymap.

`app_cli`-Rolle:

- `app_cli_packages` — Liste der CLI-Tools (Default: htop, tmux, jq, ripgrep, fd-find,
  bind-utils, lsof, tcpdump, rsync, tree, vim-enhanced, mosh, bash-completion, wget, which, file).
- `app_cli_mosh_open_firewall` / `app_cli_mosh_firewall_port_min` / `app_cli_mosh_firewall_port_max`
  — UDP-Range für mosh (Default `60000-61000/udp`).

`common_sshd`-Rolle:

- `common_sshd_dropin_path` — Pfad des sshd-Drop-ins (Default `/etc/ssh/sshd_config.d/50-devmachine.conf`).
- `common_sshd_client_alive_interval` / `common_sshd_client_alive_count_max` — Keepalive für
  Remote-Dev-Sessions (Default `60` / `3`).
- `common_sshd_max_startups`, `common_sshd_max_sessions` — Multiplex-Limits (defaults `100:30:200`
  und `20`, damit VS Code Remote-SSH genug parallele Channels öffnen kann).
- `common_sshd_tcp_keepalive`, `common_sshd_compression`, `common_sshd_use_dns` — Performance auf
  schlechten Netzen (Compression an, DNS-Lookup beim Login aus).
- `common_sshd_allow_agent_forwarding`, `common_sshd_allow_tcp_forwarding`, `common_sshd_x11_forwarding`
  — Forwarding-Policy.

`xrdp`-Rolle:

- `xrdp_packages`
- `xrdp_xfce_packages`
- `xrdp_service_name`
- `xrdp_firewall_port`
- `xrdp_open_firewall`
- `xrdp_xsession_command`
- `xrdp_skel_enabled`
- `xrdp_selinux_restorecon`
- `xrdp_xrdp_ini_entries`
- `xrdp_sesman_ini_entries`

`common_storage`-Rolle:

- `storage_setup_enabled`
- `storage_device`
- `storage_vg_name`
- `storage_lv_name`
- `storage_lv_size`
- `storage_fs_type`
- `storage_mount_point`
- `storage_mount_options`

Übergreifend:

- `vm_owner` — Liste mit genau einem User, der den Workspace-Mount besitzt und für den die
  VS Code-Extensions installiert werden.

Empfohlen: nur `devmachine_nexus_fqdn` und `devmachine_proxy_fqdn` pro Server setzen; die übrigen
Nexus-/Proxy-URLs werden standardmäßig daraus abgeleitet.

Important: `devmachine_target_users` must be set to a non-empty list of real developer accounts (not `runner`).
Each listed user receives their own workspace, tool configuration (npm/pip/pyenv) and — when
`devmachine_sudo_nopasswd: true` — a passwordless sudo entry in `/etc/sudoers.d/`.
Passwordless sudo is **disabled by default**; set `devmachine_sudo_nopasswd: true` to enable it explicitly.

VS Code-Extensions werden nur für `vm_owner[0]` installiert (Rolle `ide_vscode`), nicht für die
`devmachine_target_users`.

Git-Workspace:

- Rolle `app_git` legt `~/.ssh/` für `vm_owner[0]` an (Mode 0700). Host-Keys werden zur Laufzeit
  per `ssh-keyscan` geholt und gegen die Fingerprints aus `app_git_hosts` verifiziert — nur
  passende Keys landen in `known_hosts`. Kein TOFU, automatische Key-Rotation.
- Repos werden über `app_git_repos` als Liste von `{repo, target}`-Dicts konfiguriert. `target`
  ist immer ein absoluter Pfad **unter `/mnt/data`** (oder `app_git_target_root`, falls überschrieben).
- Geklont wird **nur dann**, wenn `~vm_owner/.ssh/id_ed25519` existiert. Fehlt der Key, gibt die
  Rolle einen Hinweis aus und überspringt die Clone-Schritte — der Rest des Playbooks läuft durch.
- Klon-Befehl: `become_user: vm_owner[0]`, `GIT_SSH_COMMAND` mit `-i ~/.ssh/id_ed25519`,
  `IdentitiesOnly=yes`, `StrictHostKeyChecking=yes`. Kein Long-Lived-Deploy-Account im Playbook.
- `update: false` — bereits geklonte Repos bleiben unangetastet, kein Auto-Pull.

pyenv + Python (rolle `app_pyenv`):

- Lädt pyenv-Tarball aus dem Nexus (Default `raw/pyenv/pyenv-2.6.31.tar.gz`), entpackt nach
  `~vm_owner/.pyenv` mit `--strip-components=1`.
- Schreibt `/etc/profile.d/app-pyenv.sh` (setzt `PYENV_ROOT`, `PATH`, `PYTHON_BUILD_MIRROR_URL`,
  führt `pyenv init` aus, sobald der User einloggt).
- Installiert `app_pyenv_python_version` (Default `3.14.5`) idempotent via `pyenv install --skip-existing`
  unter Nutzung des Nexus-Python-Source-Mirrors und des konfigurierten HTTP/HTTPS-Proxys.
- Setzt die installierte Version per `pyenv global` als Default für `vm_owner[0]`.

Java (rolle `app_java`):

- Installiert OpenJDK-Devel-Pakete via dnf aus dem RHEL 9.6 AppStream (Default 21 + 17).
- Setzt die in `app_java_default_version` gewählte Version über `alternatives --set java/javac`
  als System-Default (Default 21).
- Schreibt `/etc/profile.d/app-java.sh` mit `JAVA_HOME=/usr/lib/jvm/java-<version>-openjdk`
  und prepend `$JAVA_HOME/bin` an `PATH`.
- Für neuere LTS (z. B. 25) sobald in RHEL 9.6 AppStream verfügbar einfach
  `app_java_packages` in host_vars erweitern. Alternativen ohne dnf (Adoptium Temurin / Red Hat
  Build / Azul Zulu / Corretto / Liberica) müssten als Tarball aus Nexus eingebunden werden —
  aktuell nicht im Scope der Rolle.

Maven (rolle `app_maven`):

- Lädt Apache-Maven-Tarball aus dem Nexus (Default `raw/maven/apache-maven-3.9.16-bin.tar.gz`),
  entpackt nach `/opt/apache-maven-<version>`.
- Symlinkt `/usr/local/bin/mvn` und schreibt `/etc/profile.d/app-maven.sh` (`M2_HOME`, `PATH`).
- Schreibt `~vm_owner/.m2/settings.xml` mit zwei `<proxy>`-Einträgen (http + https) für den
  konfigurierten Corporate-Proxy und einem `<mirror mirrorOf="*">` auf das Nexus-Maven-Repository.
  Damit gehen sowohl Dependency-Resolution als auch Plugin-Downloads über Nexus via Proxy.

nvm + Node.js (rolle `app_nvm`):

- Lädt nvm-Tarball aus dem Nexus (Default `raw/nvm/nvm-0.40.4.tar.gz`), entpackt nach `~vm_owner/.nvm`.
- Schreibt `/etc/profile.d/app-nvm.sh` (setzt `NVM_DIR`, `NVM_NODEJS_ORG_MIRROR`, sourct `nvm.sh`).
- Installiert `app_nvm_node_version` (Default `v24.15.0`) per `nvm install` mit Nexus-Mirror + Proxy.
- Setzt die Version per `nvm alias default` als Default für `vm_owner[0]`.

Podman rootless:

- Rolle `app_podman` installiert podman + slirp4netns/fuse-overlayfs/crun + `policycoreutils-python-utils`.
- Container-Storage wird auf `/mnt/data/podman/{root,<vm_owner>}/storage` umgezogen
  (steuerbar via `app_podman_storage_base`). SELinux-Kontext `container_var_lib_t` wird per
  `semanage fcontext` registriert und mit `restorecon` angewendet.
- `/etc/containers/registries.conf` enthält Harbor (`app_podman_harbor_host`) als ersten
  Eintrag in `unqualified-search-registries`. Harbor wird über den bereits konfigurierten
  HTTP/HTTPS-Proxy aus `/etc/profile.d/devmachine-nexus.sh` erreicht.
- Eine vault-verschlüsselte `auth.json` (Variable `app_podman_auth_json` in
  `app_podman_auth_json_vault_file`) wird nach `/root/.config/containers/auth.json` und
  `~vm_owner/.config/containers/auth.json` (Mode 0600) deployed. Format wie Docker/Podman:
  ```yaml
  app_podman_auth_json:
    auths:
      harbor.example.com:
        auth: "<base64(user:password)>"
  ```
  Vault-Datei mit `ansible-vault create <pfad>` anlegen. Fehlt sie, gibt die Rolle einen
  Hinweis aus und überspringt das auth.json-Deployment ohne Fehler.
- Trägt `vm_owner[0]` in `/etc/subuid` und `/etc/subgid` ein (Default-Range
  `100000-165535`, konfigurierbar über `podman_subuid_start`/`podman_subuid_count`).
- `loginctl enable-linger {{ vm_owner[0] }}` damit User-Systemd-Services (z. B. `podman generate
  systemd`-Units) ohne aktiven Login laufen.
- Verifiziert anschließend `podman info` als `vm_owner[0]` (abschaltbar mit
  `podman_verify_rootless: false`).
- Optionaler Docker-CLI-Shim via `podman_docker_compat: true` (installiert `podman-docker`).

xrdp / XFCE:

- Rolle `xrdp` installiert XFCE + xrdp, aktiviert den Service und legt für `vm_owner[0]`
  `~/.xsession` **und** `~/.Xclients` an, beide mit `exec xfce4-session`.
- `/etc/skel/.xsession` und `/etc/skel/.Xclients` werden als Defaults für zukünftig angelegte
  User gesetzt (abschaltbar via `xrdp_skel_enabled: false`).
- `/etc/xrdp/xrdp.ini` und `/etc/xrdp/sesman.ini` werden via `ini_file` punktuell angepasst
  (`xrdp_xrdp_ini_entries` / `xrdp_sesman_ini_entries`). Defaults:
  - `[Globals] security_layer=negotiate`
  - Perf-Tuning für schwache Netze: `tcp_nodelay=true`, `tcp_keepalive=true`,
    `bitmap_compression=true`, `bulk_compression=true`, `new_cursors=true`, `max_bpp=24`
  - `[Security] AllowRootLogin=false`
  - Bei Änderung wird der `xrdp`-Service via Handler neu gestartet.
- SELinux: das `xrdp-selinux`-Paket bringt die Policy mit; zusätzlich wird `restorecon -RvF`
  auf `/etc/xrdp` und die xrdp-Binaries angewendet (abschaltbar via `xrdp_selinux_restorecon: false`).
- Der xrdp-Login geht über PAM, daher benötigt `vm_owner[0]` ein gesetztes Linux-Passwort
  (wird **nicht** durch die Rolle gesetzt).
- Falls firewalld aktiv ist, öffnet die Rolle TCP 3389 permanent und lädt firewalld neu.
- xrdp- und XFCE-Pakete müssen über das konfigurierte DNF-Repository auflösbar sein
  (RHEL 9.6 hat XFCE/xrdp nicht in den Standard-Repos — typischerweise EPEL oder ein
  entsprechender Nexus-Mirror).

Storage / Workspace-Mount:

- Optionale Rolle `common_storage` legt einen LVM-Stack (PV → VG → LV → XFS) auf einer leeren Disk an
  und mountet sie unter `storage_mount_point` (Default `/mnt/data`).
- Aktivierung via `storage_setup_enabled: true`. Default-Device ist `/dev/sdb`.
- `vm_owner` muss als Liste mit genau einem Eintrag gesetzt sein (z. B. `vm_owner: ['huhu']`).
  Der Mountpoint gehört diesem User; die primäre Gruppe wird automatisch aus passwd/group aufgelöst.
- Die Rolle bricht ab, wenn das Device bereits gemountet ist, die Root-Partition trägt oder
  eine nicht-LVM-Signatur enthält (Schutz vor versehentlichem Daten-Wipe). Bestehende LVM-Strukturen
  werden idempotent erkannt.
- Implementiert ausschließlich mit `ansible.builtin`-Modulen (LVM-CLI via `command`); keine
  Galaxy-Collections erforderlich.
- Workspace-Pfade der `ide`-Rolle (`devmachine_workspace_root`, `devmachine_shared_workspace_path`)
  liegen standardmäßig unter `/mnt/data` und nutzen damit den Mount, sobald `common_storage` aktiv ist.

Workspace Defaults:

- For each user in `devmachine_target_users`, a workspace is created under `{{ devmachine_workspace_root }}/{{ username }}`.
- A symlink `~/{{ devmachine_workspace_link_name }}` is created in every target user's home directory.
- The shared workspace (if enabled) is set up once, owned by the first user in the list unless `devmachine_shared_workspace_owner` is overridden.
- Optionally, a general user (default name `devuser`) can be created (`devmachine_general_user_enabled: true`).
- Note: Override the default user `devuser` via `devmachine_general_user` if needed to avoid naming conflicts.

## Ausführung

Lokaler Host (ein User):

```bash
ansible-playbook playbooks/devmachine.yml \
  -e target_hosts=localhost \
  -e '{"devmachine_target_users": ["priad11-ext"]}'
```

Remote-Hosts aus der Gruppe `devmachines` mit mehreren Usern (empfohlen: `host_vars` oder Gruppenvar):

```yaml
# inventory/host_vars/myserver.yml
devmachine_target_users:
  - priad11-ext
  - jdoe
  - msmith
```

```bash
ansible-playbook playbooks/devmachine.yml
```

Beispiel mit Vault-Bootstrap für den passwortgeschützten SSH-Key des Login-Users `ansible`:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/.vault-pass.txt
ansible-playbook playbooks/devmachine.yml
```

Beim ersten Lauf wird der lokale SSH-Key unter `devmachine_ansible_login_ssh_key_path` erzeugt
(falls er noch nicht existiert) und anschließend verschlüsselt in
`devmachine_ansible_login_ssh_key_vault_file` abgelegt (inklusive Passphrase und Private Key).
Der Standardpfad für `devmachine_ansible_login_ssh_key_vault_file` erwartet die Repo-Struktur
`playbooks/` und `inventory/` als Geschwisterverzeichnisse.
