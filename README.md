# Fedora Configuration

Personal Fedora configuration and automation repository for provisioning and maintaining my desktop, laptop, and home server systems.

The repository provides a common Fedora setup with host-specific configuration, shell configuration, SSH configuration, and university data backup/synchronisation tooling.

## Supported Systems

| System | Fedora Edition | Purpose |
|---|---|---|
| Desktop | Fedora Workstation | Primary workstation, gaming, development, and data science |
| Laptop | Fedora Workstation | Mobile development and university work |
| Mini PC | Fedora Server | Home server, container services, storage, and backup/synchronisation |

## Repository Structure

```text
.
├── config/
│   └── ssh/
│       ├── desktop.conf
│       └── laptop.conf
├── hosts/
│   ├── common/
│   │   ├── .p10k.zsh
│   │   └── .zshrc
│   └── fedora/
│       ├── desktop.sh
│       ├── laptop.sh
│       └── server.sh
├── Icons/
├── scripts/
│   ├── archive-excludes.txt
│   ├── fix-bluetooth-audio.sh
│   ├── hdd-ingest.sh
│   ├── mds_backup.env.example
│   ├── mds_backup.sh
│   ├── mds_pull.sh
│   ├── restore-fedora-data.sh
│   ├── rgb-off.sh
│   └── rsync-excludes.txt
├── .gitignore
├── README.md
└── setup-fedora.sh
```

## Fedora Setup

`setup-fedora.sh` is the main provisioning script.

It performs the common Fedora configuration required by the workstation systems, including:

- system updates;
- RPM Fusion configuration;
- Flathub configuration;
- development and command-line tools;
- desktop applications;
- Tailscale;
- container tooling;
- common utilities;
- host-specific configuration.

Run the setup from the repository root:

```bash
chmod +x setup-fedora.sh
./setup-fedora.sh
```

The setup script detects the system chassis and executes the appropriate script from:

```text
hosts/fedora/
```

## Host Configuration

### Desktop

`hosts/fedora/desktop.sh` configures the primary workstation.

This includes:

- NVIDIA drivers through RPM Fusion;
- NVIDIA CUDA support;
- NVIDIA power-management configuration;
- kernel module rebuilding;
- OpenRGB and I2C support;
- performance power profile;
- university working directories.

A reboot is recommended after the NVIDIA configuration has completed.

### Laptop

`hosts/fedora/laptop.sh` configures the mobile workstation.

This includes:

- power profile configuration;
- Lenovo IdeaPad battery conservation where supported;
- touchpad configuration;
- university working directories.

The balanced power profile is used by default.

### Server

`hosts/fedora/server.sh` configures the home mini PC running Fedora Server.

This includes:

- Podman;
- Podman Compose;
- Docker-compatible Podman tooling;
- persistent user services;
- rsync;
- rclone;
- NFS utilities.

`podman-docker` provides Docker-compatible commands for workflows that expect the `docker` command while containers continue to run through Podman.

## Networking

Tailscale provides private connectivity between systems when they are not on the same local network.

SSH configuration templates are stored under:

```text
config/ssh/
```

with separate configurations for the desktop and laptop so that each machine can use its own SSH identity.

## University Data Workflow

University work is maintained locally on the workstation systems rather than being worked on directly over network storage.

The mini PC provides a synchronisation and snapshot destination, while an external drive provides an additional local backup.

This allows university work to remain available when the home server or Internet connection is unavailable.

### Backup

The primary backup workflow is:

```bash
scripts/mds_backup.sh
```

The script manages synchronisation and backup operations between the workstation, mini PC, and external storage.

The workflow is designed so that local and external-drive backups can continue when the mini PC cannot be reached.

### Pull

To retrieve newer university data from the mini PC:

```bash
scripts/mds_pull.sh
```

The script selects an appropriate connection method and synchronises newer files into the local university working directory.

### External HDD Ingest

`scripts/hdd-ingest.sh` imports the current university working copy from the external MDS vault into the desktop working directory.

After ingestion, the normal backup workflow can be run to propagate the updated data to the remaining backup destinations.

### Restore

`scripts/restore-fedora-data.sh` restores files from a backup onto a freshly installed Fedora system:

```bash
./scripts/restore-fedora-data.sh /path/to/backup
```

To preview the restore without changing any files:

```bash
DRY_RUN=1 ./scripts/restore-fedora-data.sh /path/to/backup
```

## Backup Configuration

Runtime configuration for the MDS backup system is stored in:

```text
scripts/mds_backup.env
```

This file is intentionally excluded from Git.

An example configuration is provided:

```text
scripts/mds_backup.env.example
```

To create a local configuration:

```bash
cp scripts/mds_backup.env.example scripts/mds_backup.env
```

Then edit the values for the local system.

### Exclusions

Two exclusion files are maintained:

```text
scripts/rsync-excludes.txt
scripts/archive-excludes.txt
```

These control which files and directories are excluded from normal synchronisation and archival operations.

## Shell Configuration

Common Zsh configuration is stored under:

```text
hosts/common/
```

This includes:

- `.zshrc`;
- Powerlevel10k configuration;
- development aliases;
- university backup aliases;
- environment setup.

The configuration is shared between the Fedora workstation systems where appropriate.

## Utility Scripts

### Bluetooth Audio

```text
scripts/fix-bluetooth-audio.sh
```

Contains Bluetooth audio configuration used by supported workstation systems.

### RGB Control

```text
scripts/rgb-off.sh
```

Provides a simple RGB control utility for the desktop.

## Validation

Shell scripts can be checked with ShellCheck before committing changes:

```bash
shellcheck \
    setup-fedora.sh \
    hosts/fedora/desktop.sh \
    hosts/fedora/laptop.sh \
    hosts/fedora/server.sh \
    scripts/fix-bluetooth-audio.sh \
    scripts/hdd-ingest.sh \
    scripts/mds_pull.sh \
    scripts/mds_backup.sh \
    scripts/restore-fedora-data.sh
```

Git whitespace errors can be checked with:

```bash
git diff --check
```

## Historical CachyOS Configuration

This repository was originally used to configure CachyOS.

The final version of the previous CachyOS configuration is preserved in the Git tag:

```text
cachyos-final
```

It can be inspected without retaining obsolete CachyOS scripts in the current Fedora configuration:

```bash
git show cachyos-final
```

or checked out temporarily:

```bash
git switch --detach cachyos-final
```

Return to the Fedora development branch with:

```bash
git switch fedora-rework
```

## Security

Secrets and machine-specific environment files should not be committed to the repository.

The real:

```text
scripts/mds_backup.env
```

is ignored by Git. Only the example configuration should be committed.

Before committing changes, sensitive files can be checked with:

```bash
git status --ignored
```

## License

This project is licensed under the MIT License.

Copyright (c) 2026 Michael McMillan
