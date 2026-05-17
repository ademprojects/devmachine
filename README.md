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

- `devmachine_nexus_base_url`
- `devmachine_local_package_dir`
- `devmachine_dnf_repo_url`
- `devmachine_dnf_gpgcheck`
- `devmachine_dnf_gpgkey`
- `devmachine_npm_registry_url`
- `devmachine_pyenv_mirror_url`
- `devmachine_pip_index_url`
- `devmachine_target_user`
- `devmachine_target_group`
- `devmachine_user_home`
- `devmachine_workspace_setup_enabled`
- `devmachine_workspace_root`
- `devmachine_workspace_link_name`
- `devmachine_shared_workspace_enabled`
- `devmachine_shared_workspace_path`
- `devmachine_shared_workspace_owner`
- `devmachine_shared_workspace_group`
- `devmachine_general_user_enabled`
- `devmachine_general_user`
- `devmachine_ansible_login_user`
- `devmachine_ansible_login_ssh_key_path`
- `devmachine_ansible_login_ssh_key_passphrase`
- `devmachine_vscode_sha256`
- `devmachine_vscode_extensions`
- `devmachine_intellij_sha256`

Workspace-Defaults:

- For `devmachine_target_user`, a workspace is created under `{{ devmachine_workspace_root }}/{{ devmachine_target_user }}`.
- Im Home-Verzeichnis des Zielusers wird standardmäßig ein Symlink `~/{{ devmachine_workspace_link_name }}` darauf erstellt.
- Optional kann ein allgemeiner User (Default-Name `devuser`) angelegt werden (`devmachine_general_user_enabled: true`).
- Optional kann ein gemeinsamer Bereich unter `devmachine_shared_workspace_path` angelegt werden (`devmachine_shared_workspace_enabled: true`).
- Hinweis: Den Default-User `devuser` bei Bedarf per `devmachine_general_user` überschreiben, um Namenskonflikte zu vermeiden.

## Ausführung

Lokaler Host:

```bash
ansible-playbook playbooks/devmachine.yml -e target_hosts=localhost
```

Remote-Hosts aus der Gruppe `devmachines`:

```bash
ansible-playbook playbooks/devmachine.yml
```

Beispiel mit passwortgeschütztem neuem SSH-Key für den Login-User `ansible`:

```bash
ansible-playbook playbooks/devmachine.yml -e devmachine_ansible_login_ssh_key_passphrase='STRONG_PASSPHRASE'
```
