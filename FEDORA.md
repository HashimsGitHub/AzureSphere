# AzureSphere on Azure Linux 4.0

This version has been updated to run on Fedora while retaining Debian/Ubuntu compatibility.

## What changed

- Fedora package detection using `dnf`.
- Docker CE + Docker Compose plugin installation on Fedora, with a Moby fallback.
- Modern `docker compose` support, with legacy `docker-compose` fallback.
- Automatic `firewalld` rules for VM A and VM B service ports.
- SELinux-safe `:Z` labels for host bind mounts.
- SELinux container labeling disabled only for the VM A diagnostic agent that needs access to `/var/run/docker.sock`; SELinux remains enabled on the host.
- Deployment scripts prefer the local extracted source so the Fedora changes are not overwritten by a clone of the upstream repository.

## Fedora deployment

### VM A — Source Host

```bash
cd AzureSphere-main
chmod +x start-vma.sh
./start-vma.sh
```

### VM B — Destination Host

```bash
cd AzureSphere-main/simulator
chmod +x start-vmb.sh
./start-vmb.sh
```

The scripts install required packages and start Docker automatically.

## Verify

VM A:

```bash
sudo docker compose ps
curl http://localhost:8080/api/info
```

VM B:

```bash
sudo docker compose ps
curl http://localhost:9090/api/status
```

## Fedora firewall

The scripts configure `firewalld` automatically when it is active. You must still configure any Azure NSG, AWS Security Group, or other upstream/network firewall separately.

VM A opens TCP 80, 443, and 8080 locally.

VM B opens TCP 21, 80, 443, 445, 1433, 2222, 5432, 5555, 5671, 5672, 8080, 8443, 8888, 9090, and 30015 locally.

## SELinux

Do not disable SELinux. The Compose files use SELinux-aware volume labels. The VM A agent uses `security_opt: label=disable` only because it intentionally accesses the host Docker socket to execute traceroute in the dedicated sidecar container.
