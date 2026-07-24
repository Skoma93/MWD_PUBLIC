# Raspberry Pi Hardware Installation

## Prerequisites

- Raspberry Pi OS 64-bit
- Docker Engine with Docker Compose v2
- PLC connected through USB/serial
- Local Authentik/OIDC and PostgreSQL containers (included)
- Public `mvd/web` and `mvd/backend` GHCR packages

## 1. Install Docker

Follow Docker's official Raspberry Pi OS installation guide:

https://docs.docker.com/engine/install/raspberry-pi-os/

Verify the installation:

```sh
docker --version
docker compose version
sudo docker run --rm hello-world
```

Allow the current user to run Docker:

```sh
sudo usermod -aG docker "$USER"
```

Log out and back in, then verify:

```sh
docker info
```

## 2. Download the deployment repository

```sh
cd /opt
sudo git clone https://github.com/Skoma93/MWD_PUBLIC.git mwd
sudo chown -R "$USER":"$USER" /opt/mwd
cd /opt/mwd
chmod +x install.sh manage.sh
```

The private source repository and a GitHub token are not required when the
container packages are public.

## 3. Find the PLC serial port

Connect the USB-to-serial adapter and run:

```sh
ls -l /dev/serial/by-id/
```

Prefer the complete stable path, for example:

```text
/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AB0ABC-if00-port0
```

If `/dev/serial/by-id` is unavailable:

```sh
dmesg | grep -E 'ttyUSB|ttyACM'
```

## 4. Create the configuration

Run the installer once:

```sh
cd /opt/mwd
./install.sh hardware
```

The first run creates `.env.common` and `.env.hardware`, then stops so they can
be configured.

## 5. Configure common settings

Open the common environment:

```sh
nano .env.common
```

Keep the published image coordinates:

```dotenv
MWD_IMAGE_REGISTRY=ghcr.io/skoma93/mvd
MWD_IMAGE_TAG=v0.1.0
```

Set the machine identity and web port:

```dotenv
SYSTEM_HOSTNAME=mwd-machine
WEB_PORT=8080
```

Configure the included Authentik instance using values for the installed machine. Also replace every `AUTHENTIK_*`, `MWD_SIM_*`, and session-secret placeholder created from `.env.common.example`:

```dotenv
AUTHENTIK_ISSUER_URL=https://auth.your-domain.com/application/o/microwave-drying-machine/
AUTHENTIK_CLIENT_ID=microwave-drying-machine
AUTHENTIK_CLIENT_SECRET=YOUR_AUTHENTIK_CLIENT_SECRET
AUTHENTIK_REDIRECT_URI=https://mwd.your-domain.com/auth/callback
AUTHENTIK_POST_LOGOUT_REDIRECT_URI=https://mwd.your-domain.com/
SESSION_SECRET=GENERATE_A_LONG_RANDOM_VALUE
SESSION_COOKIE_SECURE=true
```

Generate a session secret:

```sh
openssl rand -hex 32
```

The included bootstrap job creates the provider, signing key, initial users, and the application groups `viewer`, `operator`, and `admin`.

Save Nano with `Ctrl+O`, Enter, and `Ctrl+X`.

## 6. Configure the PLC connection

Open the hardware environment:

```sh
nano .env.hardware
```

Set the serial device to the path found earlier:

```dotenv
PLC_MODE=serial
PLC_SERIAL_DEVICE=/dev/serial/by-id/usb-YOUR-ADAPTER
PLC_SERIAL_BAUDRATE=19200
PLC_SERIAL_PARITY=N
PLC_SERIAL_DATA_BITS=8
PLC_SERIAL_STOP_BITS=1
CAMERA_STREAM_URL=
```

The serial parameters must match the PLC.

## 7. Install and start hardware mode

```sh
cd /opt/mwd
./install.sh hardware
```

The installer pulls the versioned images, maps the serial device into the
backend, starts the services, and displays their status.

## 8. Verify operation

Show service status:

```sh
./manage.sh status
```

Follow logs:

```sh
./manage.sh logs
```

Find the Raspberry Pi address:

```sh
hostname -I
```

Without a reverse proxy, the direct LAN address is normally:

```text
http://RPI_IP_ADDRESS:8080
```

When `SESSION_COOKIE_SECURE=true`, authentication requires HTTPS through a
trusted reverse proxy.

## Update

Change `MWD_IMAGE_TAG` in `.env.common` when a new tested release is available,
then run:

```sh
cd /opt/mwd
git pull
./manage.sh pull
./manage.sh start-hardware
./manage.sh status
```

## Stop

```sh
cd /opt/mwd
./manage.sh stop
```

## Current hardware limitation

The current hardware adapter reads PLC telemetry only. Hardware recipe writes
and commands such as start, stop, abort, vent, and reset are not yet enabled or
safety-validated.
