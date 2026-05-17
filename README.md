# devmachine

Ansible-Setup für eine RHEL-9.6-Entwicklermaschine mit:

- VS Code (Linux RPM aus lokal kopierter Datei)
- VS Code Extensions für Ansible und Python (lokale VSIX-Dateien)
- IntelliJ IDEA (Linux tar.gz aus lokal kopierter Datei)
- Java-Entwicklungspaketen über ein Nexus-Repository
- Nexus-Konfiguration für `npm` und `pyenv`/`pip`

## Voraussetzungen

- Steuerrechner mit Ansible
- Zielsystem(e): RHEL 9.6
- VS Code RPM und IntelliJ tar.gz wurden vorab auf den Steuerrechner kopiert (Standard: `./packages`)

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

Danach Dateien explizit auf den Steuerrechner legen:

```bash
mkdir -p ./packages
cp ./downloads/code-latest.x86_64.rpm ./packages/
cp ./downloads/ideaIC-latest.tar.gz ./packages/
cp ./downloads/redhat.ansible.vsix ./packages/
cp ./downloads/ms-python.python.vsix ./packages/
```

Die Rolle `ide` kopiert die Dateien dann auf die Zielhosts und installiert VS Code, IntelliJ sowie die VS Code-Extensions dort.

## Konfiguration

Standardwerte stehen in `roles/ide/defaults/main.yml` und können via `-e` überschrieben werden, z. B.:

- `devmachine_nexus_fqdn`
- `devmachine_proxy_fqdn`
- `devmachine_nexus_base_url`
- `devmachine_local_package_dir`
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
- `devmachine_vscode_sha256`
- `devmachine_vscode_extensions`
- `devmachine_intellij_sha256`

Empfohlen: nur `devmachine_nexus_fqdn` und `devmachine_proxy_fqdn` pro Server setzen; die übrigen
Nexus-/Proxy-URLs werden standardmäßig daraus abgeleitet.

Important: `devmachine_target_users` must be set to a non-empty list of real developer accounts (not `runner`).
Each listed user receives their own workspace, VS Code extensions, tool configuration, and — when
`devmachine_sudo_nopasswd: true` — a passwordless sudo entry in `/etc/sudoers.d/`.
Passwordless sudo is **disabled by default**; set `devmachine_sudo_nopasswd: true` to enable it explicitly.

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
