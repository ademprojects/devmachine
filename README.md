# devmachine

Ansible-Setup für eine RHEL-9.6-Entwicklermaschine mit:

- VS Code (Linux RPM aus lokal kopierter Datei)
- IntelliJ IDEA (Linux tar.gz aus lokal kopierter Datei)
- Java-Entwicklungspaketen über ein Nexus-Repository
- Nexus-Konfiguration für `npm` und `pyenv`/`pip`

## Voraussetzungen

- Steuerrechner mit Ansible
- Zielsystem(e): RHEL 9.6
- VS Code RPM und IntelliJ tar.gz wurden vorab per `scp` nach `/opt/devmachine/packages` kopiert

## Linux-Pakete per PowerShell herunterladen

```powershell
pwsh -File ./tools/download-linux-ide-packages.ps1 -OutputDirectory ./downloads
```

Danach Dateien z. B. so auf das Zielsystem kopieren:

```bash
scp ./downloads/* user@rhel96:/opt/devmachine/packages/
```

## Konfiguration

Standardwerte stehen in `roles/devmachine/defaults/main.yml` und können via `-e` überschrieben werden, z. B.:

- `devmachine_nexus_base_url`
- `devmachine_dnf_repo_url`
- `devmachine_npm_registry_url`
- `devmachine_pyenv_mirror_url`
- `devmachine_pip_index_url`
- `devmachine_target_user`

## Ausführung

Lokaler Host:

```bash
ansible-playbook playbooks/devmachine.yml -e target_hosts=localhost
```

Remote-Hosts aus der Gruppe `devmachines`:

```bash
ansible-playbook playbooks/devmachine.yml
```
