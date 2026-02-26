# Homelab Project Context

This project is a multi-layered NixOS-based homelab configuration. It uses Nix Flakes, `flake-parts`, and `deploy-rs` for infrastructure management.

## Project Structure

- **`l1/` (Layer 1):** The foundation layer focusing on low-level infrastructure, bare-metal host configurations, and core modules.
    - **`hosts/`**: Contains individual host configurations (e.g., `frost`, `hades`, `terra`). Each host defines its own `nixosSystem` and deployment settings.
    - **`modules/`**: Shared NixOS modules for networking, boot, users, ZFS, iSCSI, and netboot.
    - **`bootstrap/`**: Logic for generating bootstrap images (ISO/Netboot) used for initial provisioning.
- **`l2/` (Layer 2):** Intended for higher-level services and applications (currently placeholder).
- **`flake.nix`**: The main entry point for the Nix Flake, managing dependencies and exporting configurations.
- **`justfile`**: A command runner containing automation for common tasks like flashing ISOs and deploying hosts.

## Building and Running

Common operations are managed via `just`:

- **List hosts:** `just hosts`
- **Deploy a host:** `just deploy <host>`
- **Deploy all hosts:** `just deploy_all`
- **Flash a bootstrap ISO:** `just flash <host> <device>`
- **Generate hardware config (for new hosts):** `just hwconfig <host>`
- **Wipe a device:** `just wipe <device>`

## Development Conventions

- **Modular Design:** Functionality is encapsulated in NixOS modules under `l1/modules/`. Host configurations should import `../../modules` to leverage shared settings.
- **Bootstrapping:** Hosts typically define both a `bootstrapNetboot` (or similar) and a `targetSystem`. Initial setup often involves flashing or netbooting a minimal installer.
- **Deployment:** `deploy-rs` is used for pushing configurations to remote hosts.
- **State Version:** The current target state version for the lab is `25.11`.

## Key Technologies

- **Nix / NixOS**: Core configuration and package management.
- **Flake-parts**: Modularizing the flake structure.
- **Deploy-rs**: Remote deployment tool.
- **Just**: Task automation.
- **ZFS & iSCSI**: Storage technologies used in modules.
