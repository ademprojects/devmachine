# devmachine

Ansible-Setup für eine RHEL-9.6-Entwicklermaschine mit:

- VS Code (Linux RPM aus `roles/ide_vscode/files/`)
- VS Code Extensions für Ansible und Python (VSIX-Dateien aus `roles/ide_vscode/files/`)
- IntelliJ IDEA (Linux tar.gz aus `roles/ide_intellij/files/`)
- Google Chrome (RPM aus `roles/chrome/files/`)
- XFCE-Desktop mit xrdp (RDP-Zugriff für `vm_owner[0]`)
- Java-Entwicklungspaketen über ein Nexus-Repository
- Nexus-Konfiguration für `npm` und `pyenv`/`pip`

## Voraussetzungen

- Steuerrechner mit Ansible
- Zielsystem(e): RHEL 9.6
- Die Quell-Pakete liegen in den Rollen-Ordnern `roles/ide_vscode/files/` (RPM + VSIX),
  `roles/ide_intellij/files/` (tar.gz) und `roles/chrome/files/` (Chrome-RPM) — werden manuell
  dort hineinkopiert.
- Für die `xrdp`-Rolle müssen XFCE- und xrdp-Pakete via dnf installierbar sein (typisch via
  EPEL oder einen entsprechenden Nexus-Mirror).
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
cp ./downloads/redhat.ansible.vsix                    ./roles/ide_vscode/files/
cp ./downloads/ms-python.python.vsix                  ./roles/ide_vscode/files/
cp ./downloads/idea-2026.1.2.tar.gz                   ./roles/ide_intellij/files/
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

- `ide_vscode_rpm`
- `ide_vscode_sha256`
- `ide_vscode_extensions`
- `ide_vscode_package_dir`

`ide_intellij`-Rolle:

- `ide_intellij_archive`
- `ide_intellij_sha256`
- `ide_intellij_install_dir`
- `ide_intellij_symlink`
- `ide_intellij_package_dir`

`chrome`-Rolle:

- `chrome_rpm`
- `chrome_sha256`
- `chrome_package_dir`

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

xrdp / XFCE:

- Rolle `xrdp` installiert XFCE + xrdp, aktiviert den Service und legt für `vm_owner[0]`
  `~/.xsession` **und** `~/.Xclients` an, beide mit `exec xfce4-session`.
- `/etc/skel/.xsession` und `/etc/skel/.Xclients` werden als Defaults für zukünftig angelegte
  User gesetzt (abschaltbar via `xrdp_skel_enabled: false`).
- `/etc/xrdp/xrdp.ini` und `/etc/xrdp/sesman.ini` werden via `ini_file` punktuell angepasst
  (`xrdp_xrdp_ini_entries` / `xrdp_sesman_ini_entries`). Default: `security_layer=negotiate`
  und `AllowRootLogin=false`. Bei Änderung wird der `xrdp`-Service via Handler neu gestartet.
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
