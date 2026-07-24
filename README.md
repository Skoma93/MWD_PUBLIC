# Microwave Drying Machine: Container-Only Deployment

This directory is a standalone deployment repository template. It contains no application source
code and never builds images on the target computer. Docker Compose pulls versioned web, backend,
and simulator images from a registry such as GitHub Container Registry (GHCR).

## Source-code privacy model

Keep the full application repository **private**. Make only this deployment repository public.
The public repository contains installation scripts and image coordinates, while releases are
built by CI in the private source repository.

This separation prevents people from cloning the original Dart and Python Git history, but public
container images are downloadable artifacts—not a secrecy boundary. A user can inspect image
layers, and the current backend image contains installed Python modules while the web image contains
compiled Flutter JavaScript. Either can be studied or reverse-engineered. No obfuscator can make
client-delivered or locally executed software impossible to recover.

Choose one distribution model:

- **Public installer + public GHCR images:** anyone can install; source is not published, but image
  contents can be inspected.
- **Public installer + private GHCR images:** only customers with a read-only GHCR token can pull;
  access is controlled, but an authorized customer can still inspect downloaded images.
- **Hosted service:** keep backend images on infrastructure you control and expose only the web/API;
  this gives the strongest backend secrecy but does not support an offline machine controller.

Use copyright and license terms in addition to technical controls. A future release pipeline can
compile selected backend modules and strip build metadata, but that is a separate engineering effort
and still cannot guarantee secrecy.

## Publish this folder as its own Git repository

Copy only the contents of `container-deployment/` into a new private deployment repository. Do not
copy private `.env.common`, `.env.simulation`, `.env.hardware`, source directories, credentials, Docker volumes, logs, or machine data.

```sh
git init
git add .
git commit -m "deploy: add container-only bundle"
git branch -M main
git remote add origin https://github.com/Skoma93/MWD_PUBLIC.git
git push -u origin main
```

The deployment repository does not build the application because it intentionally has no source.
The source repository publishes images using `.github/workflows/publish-images.yml`. Published image
paths are:

```text
ghcr.io/skoma93/mvd/web:TAG
ghcr.io/skoma93/mvd/backend:TAG
ghcr.io/skoma93/mvd/simulator:TAG
```

Use a release tag or commit SHA in production, not `latest`. For private GHCR packages, authenticate
the target host with a read-only token:

```sh
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u YOUR-GITHUB-USER --password-stdin
```

Never put the token in `.env`, Compose, Git history, or a command that exposes it in shell history.

## Configure a target host

Requirements are Docker Engine/Desktop with Compose v2, network access to the registry, an existing
OIDC provider, and enough disk space for the images and persistent data. Hardware mode is supported
only on Linux and needs the exact serial device path.

```sh
cp .env.common.example .env.common
cp .env.simulation.example .env.simulation   # or hardware
# Replace every placeholder. Keep these files private.
docker compose --env-file .env.common --env-file .env.simulation -f compose.yml -f compose.simulation.yml config --quiet
```

### One-command installation

On first invocation, the installer creates `.env.common` and the selected `.env.simulation` or
`.env.hardware`, then stops. Replace every placeholder and rerun it; it pulls and starts the
frontend, backend, and selected PLC mode.

Windows PowerShell:

```powershell
.\install.ps1 -Mode simulation
# Hardware is only for an approved Linux hardware host.
.\install.ps1 -Mode hardware
```

Linux:

```sh
chmod +x install.sh manage.sh
./install.sh simulation
# or: ./install.sh hardware
```

PowerShell uses the equivalent commands automatically:

```powershell
.\manage.ps1 -Command pull
.\manage.ps1 -Command start-simulation
.\manage.ps1 -Command status
```

Linux:

```sh
chmod +x manage.sh
./manage.sh pull
./manage.sh start-simulation
./manage.sh status
```

Authentik and PostgreSQL are included and start in both modes. The bootstrap job creates the OIDC
provider, signing key, application groups `viewer`, `operator`, and `admin`, and initial users.
Set every Authentik secret, initial-user password, issuer URL, callback URL, and logout URL in
`.env.common`. For plain HTTP on an isolated LAN, use `SESSION_COOKIE_SECURE=false`; production
HTTPS still requires a trusted reverse proxy.

## Update and operate

Change `MWD_IMAGE_TAG` to a tested immutable tag, then pull and recreate the chosen mode:

```powershell
.\manage.ps1 -Command pull
.\manage.ps1 -Command start-simulation
```

```sh
./manage.sh pull
./manage.sh start-simulation
```

Operational commands preserve named volumes:

```sh
./manage.sh status
./manage.sh logs
./manage.sh stop
```

Compose stores recipes and preferences in `backend-data`; simulator state is in `simulator-data`.
There is not yet a validated backup/restore or schema-migration procedure. Do not delete volumes,
run `down --volumes`, or upgrade across incompatible versions without a tested backup and rollback.

## Hardware boundary

Hardware mode is intentionally separate:

```sh
./manage.sh start-hardware
```

It maps only `PLC_SERIAL_DEVICE` into the backend and does not start the simulator. Prefer a stable
`/dev/serial/by-id/...` path. The current adapter reads serial telemetry only: recipe load, start,
live apply, stop, abort, vent, and reset are not enabled for hardware.

The current `kinco-unverified-v1` register profile has no bench validation, and production TLS,
backup/restore, audit, restart recovery, hardware writes, and safety acceptance remain incomplete.
Therefore this bundle is suitable for deploying immutable containers and production-like
infrastructure, but it must not be represented as approved for controlling a production microwave
machine until the safety gates in the source repository are completed.
