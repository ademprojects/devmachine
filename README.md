# devmachine

Ansible-Setup für eine RHEL-9.6-Entwicklermaschine mit:

- VS Code (Linux RPM aus `roles/app_vscode/files/`)
- VS Code Plugins (alle `*.vsix` aus `roles/app_vscode/files/plugins/` werden auto-discovered)
- IntelliJ IDEA (Linux tar.gz aus `roles/app_intellij/files/`, Plugins als `.zip`/`.jar` aus `roles/app_intellij/files/plugins/`)
- Google Chrome (RPM aus `roles/app_chrome/files/`)
- Postman (Tarball aus `roles/app_postman/files/`)
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
- Die Quell-Pakete liegen in den Rollen-Ordnern `roles/app_vscode/files/` (RPM, VSIX-Plugins
  unter `files/plugins/`),
  `roles/app_intellij/files/` (tar.gz, Plugins unter `files/plugins/`), `roles/app_chrome/files/` (Chrome-RPM)
  und `roles/app_postman/files/` (Postman-Tarball) — werden manuell
  dort hineinkopiert.
- EPEL-Pakete müssen via dnf installierbar sein. Die Rollen `common_xrdp` (XFCE + xrdp) und
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
cp ./downloads/code-1.120.0-1778619100.el8.x86_64.rpm ./roles/app_vscode/files/
cp ./downloads/*.vsix                                 ./roles/app_vscode/files/plugins/
cp ./downloads/idea-2026.1.2.tar.gz                   ./roles/app_intellij/files/
cp ./downloads/intellij-plugins/*.zip                 ./roles/app_intellij/files/plugins/
```

Die Rollen `app_vscode` und `app_intellij` kopieren die Dateien dann auf den Zielhost und
installieren VS Code (systemweit, plus VSIX-Extensions für `vm_owner[0]`) bzw. IntelliJ
(systemweit unter `/opt/jetbrains/idea-*` mit Symlink `/usr/local/bin/idea`).

## VS Code- und IntelliJ-Plugins per Skript holen

```bash
bash tools/download-ide-plugins.sh
```

Lädt die in der `VSCODE_EXTENSIONS`- und `INTELLIJ_PLUGINS`-Liste im Skript konfigurierten
Plugins per `curl` aus Marketplace bzw. JetBrains-Marketplace nach
`roles/app_vscode/files/plugins/` und `roles/app_intellij/files/plugins/`. Die Rollen
ziehen alle dort liegenden `*.vsix` bzw. `*.zip` automatisch (Auto-Discovery, keine
Plugin-Liste in Defaults pflegen).

## Standalone-Tools per Skript holen

```bash
bash tools/download-tools.sh
```

Lädt aktuell den Postman-Tarball nach `roles/app_postman/files/`. Pattern: das Skript holt
die Quelle, du committest die Datei (oder lässt sie .gitignored), die Rolle installiert
beim nächsten Playbook-Lauf.

## Konfiguration

Standardwerte stehen in den jeweiligen `roles/<rolle>/defaults/main.yml` und können via `-e`
überschrieben werden, z. B.:

`app_workspace`-Rolle:

- `app_workspace_root` (Default `{{ common_storage_mount_point }}/work`, also `/mnt/data/work`) — Verzeichnis
  unter dem Daten-Mount für alle Projekte des Users.
- `app_workspace_link_name` (Default `work`) — Name des Symlinks im Home-Verzeichnis.

`common_sudo`-Rolle:

- `common_sudo_nopasswd` (Default `false`) — wenn `true`, passwordless sudo für `vm_owner[0]`
  in `/etc/sudoers.d/{{ vm_owner[0] }}`.

`app_vscode`-Rolle:

- `app_vscode_rpm` — Dateiname des VS Code RPMs in `files/`.
- `app_vscode_sha256` — optionale SHA256-Prüfung des RPMs.
- `app_vscode_package_dir` — Zielverzeichnis auf dem Host (Default `/opt/devmachine/packages`).
- `app_vscode_plugins_subdir` — Unterverzeichnis unter `files/` für VSIX-Plugins (Default `plugins`).
  Alle `*.vsix` darin werden automatisch erkannt, auf den Host kopiert und für `vm_owner[0]`
  installiert. Drop-File → nächster Lauf zieht es hoch.

`app_intellij`-Rolle:

- `app_intellij_archive` — Dateiname des IntelliJ-Tarballs in `files/`.
- `app_intellij_sha256` — optionale SHA256-Prüfung des Tarballs.
- `app_intellij_install_dir` — Basis für die Extraktion (Default `/opt/jetbrains`).
- `app_intellij_symlink` — Symlink zum `idea`-Launcher.
- `app_intellij_package_dir` — Staging-Ort des Tarballs auf dem Host.
- `app_intellij_plugins_subdir` — Unterverzeichnis unter `files/` für Plugins (Default `plugins`).
  Alle `*.zip` darin werden in `<INSTALL>/plugins/` entpackt, alle `*.jar` direkt dort abgelegt.
  Drop-File → nächster Lauf zieht es hoch. **Achtung:** bei IntelliJ-Update wird das alte
  `idea-*`-Dir gewipt, Plugins werden im selben Lauf neu installiert.

`app_chrome`-Rolle:

- `app_chrome_rpm`
- `app_chrome_sha256`
- `app_chrome_package_dir`

`app_postman`-Rolle:

- `app_postman_package_dir` — Staging-Verzeichnis auf dem Host.
- `app_postman_install_dir` (Default `/opt/Postman`) — Zielverzeichnis nach Extraction.
- `app_postman_executable_name` (Default `Postman`) — Name des Launcher-Binarys im Install-Dir.
- `app_postman_symlink` (Default `/usr/local/bin/postman`).
- `app_postman_desktop_entry` / `app_postman_desktop_icon` — Pfad + Icon-Pfad
  für `/usr/share/applications/postman.desktop`. Icon-Default zeigt auf den Standard-Pfad
  innerhalb des Tarballs; bei abweichender Struktur per host_vars überschreiben.
- Tarball wird per Auto-Discovery aus `roles/app_postman/files/*.tar.gz` erkannt;
  genau ein Tarball muss vorhanden sein.

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
      target: /mnt/data/work/git/service-a
    - repo: git@github.com:org/service-b.git
      target: /mnt/data/work/git/service-b
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
- `app_pyenv_pip_index_url` — pip-Index für `~vm_owner/.pip/pip.conf` (Default = `devmachine_pip_index_url`).
- `app_pyenv_build_dependencies` — Pakete für `pyenv install` (gcc, make, *-devel).
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
- `app_nvm_npm_registry_url` — npm-Registry für `~vm_owner/.npmrc` (Default = `devmachine_npm_registry_url`).
- `app_nvm_proxy_url` — HTTP/HTTPS-Proxy für den `nvm install`-Lauf.
- `app_nvm_install_subdir`, `app_nvm_profile_path` — Verzeichnis und Profile-Snippet.

`common_nexus`-Rolle (Foundation — alle anderen Rollen referenzieren die Variablen):

- `devmachine_nexus_fqdn` / `devmachine_nexus_scheme` / `devmachine_nexus_repository_path` — Nexus-Endpoint.
- `devmachine_proxy_fqdn` / `devmachine_proxy_port` / `devmachine_proxy_scheme` — HTTP-Proxy.
- `devmachine_nexus_base_url`, `devmachine_proxy_url` — aus obigen abgeleitet.
- `devmachine_dnf_repo_*` — Konfiguration des Nexus-DNF-Repos (Name, URL, GPG).
- `devmachine_npm_registry_url`, `devmachine_pip_index_url`, `devmachine_pyenv_mirror_url` — Mirror-URLs.
- `common_nexus_profile_path` (Default `/etc/profile.d/devmachine-nexus.sh`), `common_nexus_no_proxy`
  (Default `localhost,127.0.0.1`) — Inhalt des Profile-Snippets (PIP_INDEX_URL + HTTP/HTTPS_PROXY).

`common_packages`-Rolle:

- `common_packages_dnf_config_path` (Default `/etc/dnf.conf`).
- `common_packages_proxy_url` (Default `{{ devmachine_proxy_url }}`) — wird als `proxy=` in dnf.conf eingetragen.
- `common_packages_gpgcheck`, `common_packages_installonly_limit`, `common_packages_clean_requirements_on_remove`,
  `common_packages_keepcache`, `common_packages_best`, `common_packages_skip_if_unavailable` — dnf-Optionen.
- `common_packages_full_update_enabled` (Default `false`) — wenn `true`, läuft `dnf update *`
  bei jedem Playbook-Run. Sonst Update-Task wird übersprungen.

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

`common_dev_firewall`-Rolle:

- `common_dev_firewall_enabled` (Default `true`) — Gating-Flag.
- `common_dev_firewall_tcp_ports` (Default `[]`) — Liste von Ports/Ranges (Strings wie `"3000"`
  oder `"3000-3010"`), die in firewalld permanent für TCP geöffnet werden. firewalld wird
  per Handler einmalig reloaded wenn ein Port hinzukam.
- `common_dev_firewall_udp_ports` (Default `[]`) — dito für UDP.
- Typische Frontend-Dev-Server-Ports (3000/5173/8080/4200/8000) als Vorschlag in den Defaults
  kommentiert — du aktivierst nur was du brauchst, pro host_vars.

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

`common_xrdp`-Rolle:

- `common_xrdp_packages`
- `common_xrdp_xfce_packages`
- `common_xrdp_service_name`
- `common_xrdp_firewall_port`
- `common_xrdp_open_firewall`
- `common_xrdp_xsession_command`
- `common_xrdp_skel_enabled`
- `common_xrdp_selinux_restorecon`
- `common_xrdp_ini_entries`
- `common_xrdp_sesman_ini_entries`

`common_storage`-Rolle:

- `common_storage_setup_enabled`
- `common_storage_device`
- `common_storage_vg_name`
- `common_storage_lv_name`
- `common_storage_lv_size`
- `common_storage_fs_type`
- `common_storage_mount_point`
- `common_storage_mount_options`

Übergreifend:

- `vm_owner` — Liste mit genau einem User, der den Workspace-Mount besitzt und für den die
  VS Code-Extensions installiert werden.

Empfohlen: nur `devmachine_nexus_fqdn` und `devmachine_proxy_fqdn` pro Server setzen; die übrigen
Nexus-/Proxy-URLs werden standardmäßig daraus abgeleitet.

Passwordless sudo für `vm_owner[0]` ist **disabled by default**; setze `common_sudo_nopasswd: true`
um es zu aktivieren.

Alle per-User-Tasks (Workspace, `~/.npmrc`, `~/.pip/pip.conf`, VS Code-Extensions, sudo, Git-Identity,
xrdp-`.xsession`, podman rootless, etc.) laufen für `vm_owner[0]`.

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

- Rolle `common_xrdp` installiert XFCE + xrdp, aktiviert den Service und legt für `vm_owner[0]`
  `~/.xsession` **und** `~/.Xclients` an, beide mit `exec xfce4-session`.
- `/etc/skel/.xsession` und `/etc/skel/.Xclients` werden als Defaults für zukünftig angelegte
  User gesetzt (abschaltbar via `common_xrdp_skel_enabled: false`).
- `/etc/xrdp/xrdp.ini` und `/etc/xrdp/sesman.ini` werden via `ini_file` punktuell angepasst
  (`common_xrdp_ini_entries` / `common_xrdp_sesman_ini_entries`). Defaults:
  - `[Globals] security_layer=negotiate`
  - Perf-Tuning für schwache Netze: `tcp_nodelay=true`, `tcp_keepalive=true`,
    `bitmap_compression=true`, `bulk_compression=true`, `new_cursors=true`, `max_bpp=24`
  - `[Security] AllowRootLogin=false`
  - Bei Änderung wird der `xrdp`-Service via Handler neu gestartet.
- SELinux: das `xrdp-selinux`-Paket bringt die Policy mit; zusätzlich wird `restorecon -RvF`
  auf `/etc/xrdp` und die xrdp-Binaries angewendet (abschaltbar via `common_xrdp_selinux_restorecon: false`).
- Der xrdp-Login geht über PAM, daher benötigt `vm_owner[0]` ein gesetztes Linux-Passwort
  (wird **nicht** durch die Rolle gesetzt).
- Falls firewalld aktiv ist, öffnet die Rolle TCP 3389 permanent und lädt firewalld neu.
- xrdp- und XFCE-Pakete müssen über das konfigurierte DNF-Repository auflösbar sein
  (RHEL 9.6 hat XFCE/xrdp nicht in den Standard-Repos — typischerweise EPEL oder ein
  entsprechender Nexus-Mirror).

Storage / Workspace-Mount:

- Optionale Rolle `common_storage` legt einen LVM-Stack (PV → VG → LV → XFS) auf einer leeren Disk an
  und mountet sie unter `common_storage_mount_point` (Default `/mnt/data`).
- Aktivierung via `common_storage_setup_enabled: true`. Default-Device ist `/dev/sdb`.
- `vm_owner` muss als Liste mit genau einem Eintrag gesetzt sein (z. B. `vm_owner: ['huhu']`).
  Der Mountpoint gehört diesem User; die primäre Gruppe wird automatisch aus passwd/group aufgelöst.
- Die Rolle bricht ab, wenn das Device bereits gemountet ist, die Root-Partition trägt oder
  eine nicht-LVM-Signatur enthält (Schutz vor versehentlichem Daten-Wipe). Bestehende LVM-Strukturen
  werden idempotent erkannt.
- Implementiert ausschließlich mit `ansible.builtin`-Modulen (LVM-CLI via `command`); keine
  Galaxy-Collections erforderlich.
- Workspace-Pfad der `app_workspace`-Rolle (Default `/mnt/data/work`) liegt unter dem Mount,
  sobald `common_storage` aktiv ist.
- Podman-Container-Storage (`app_podman_storage_base`, Default `/mnt/data/containers`) ebenfalls.

Workspace:

- `vm_owner[0]` bekommt einen Workspace unter `{{ app_workspace_root }}` (Default `/mnt/data/work/`)
  + Symlink `~/{{ app_workspace_link_name }}` (Default `~/work`).

## Ausführung

```bash
ansible-playbook playbooks/devmachine.yml \
  -e target_hosts=localhost \
  -e '{"vm_owner": ["huhu"]}'
```

Für Remote-Hosts den User-Namen in `host_vars/myserver.yml` setzen:

```yaml
# inventory/host_vars/myserver.yml
vm_owner:
  - huhu
```

```bash
ansible-playbook playbooks/devmachine.yml
```

