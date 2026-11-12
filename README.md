# workshop-setup

Setup for the QCon San Francisco workshop "Effective AI-native Development with Harness Engineering", Friday 20 November 2026. Please do it before the day.

The workshop runs in a container that holds Claude Code, OpenCode, Java 17 and everything PetClinic needs to build. You can run that container in one of two ways. Both are fully supported, and both give you the same tools.

When you have finished, run the check and send us its summary block by replying to the email that brought you here.

## Choose one option

| | Option A: Docker on your laptop | Option B: GitHub Codespaces |
|---|---|---|
| Where the container runs | On your laptop | In GitHub's cloud; you use it from your browser |
| What you install | Docker and git | Nothing |
| What you need | macOS 13 or later, Linux, or Windows 10 or 11 with WSL 2; 8 GB of memory; 10 GB of free disk | A personal GitHub account |
| Where you read the code | In your own editor | In the editor in the browser |
| What needs the network on the day | Claude's answers | Everything, the terminal included |
| Time to set up | About 15 minutes, most of it one download | A few minutes |

**Choose A** if Docker already runs on your laptop, or you can install it.

**Choose B** if your employer manages your laptop, or you would rather install nothing.

Either way you need a Claude subscription (Pro, Max, Team or Enterprise) or an Anthropic Console account. A Pro plan may reach its usage limit during the day; Max or a Console account is the safer choice.

## Option A: Docker on your laptop

On Windows, install Ubuntu with `wsl --install` in PowerShell, then do every step below in the Ubuntu terminal. Keep the workshop folders in your Linux home folder (`~/Projects/qcon-workshop`). Folders under `/mnt/c` are slow from WSL. PowerShell and CMD aren't supported.

### A1. Docker

Any of these works:

- macOS: [Docker Desktop](https://docs.docker.com/desktop/), [OrbStack](https://orbstack.dev) or [Colima](https://github.com/abiosoft/colima).
- Windows: Docker Desktop with its WSL 2 backend, and WSL integration switched on for your Ubuntu distribution.
- Linux: [Docker Engine](https://docs.docker.com/engine/install/) with the Compose plugin.

Give Docker at least 4 GB of memory. If your employer manages your laptop, check its rules for Docker Desktop first, or choose option B.

Then check that Docker runs and has Compose:

```bash
docker compose version
```

You also need git. macOS: `xcode-select --install`. Ubuntu and WSL: `sudo apt-get install -y git curl`.

### A2. Clone the two repositories

Use exactly these paths. The container expects the two folders side by side.

```bash
mkdir -p ~/Projects/qcon-workshop
git clone https://github.com/qcon-ai-native-development/workshop-setup.git ~/Projects/qcon-workshop/workshop-setup
git clone https://github.com/qcon-ai-native-development/petclinic.git ~/Projects/qcon-workshop/petclinic
```

`petclinic` is the sandbox: the application we work on in the workshop.

### A3. Download the image and start the container

```bash
cd ~/Projects/qcon-workshop/workshop-setup
docker compose pull
docker compose up -d
```

The download is about 0.7 GB, and the image takes about 1.5 GB of disk. Download it at home; the venue's network is shared by everyone in the room.

Every `docker compose` command in this file runs from `~/Projects/qcon-workshop/workshop-setup`.

### A4. Sign in to Claude Code

```bash
docker compose exec -w /home/node workshop claude
```

Claude Code starts in the container and asks how you want to sign in. It prints a link. Open the link in your laptop's browser, approve, and paste the code back into the terminal. Then leave with `/exit`.

The sign-in is kept in a Docker volume, so you do this once. It stays on your laptop.

The command starts Claude Code in the container's home folder, away from the sandbox. Please keep it that way until the workshop.

**OpenCode** is in the container too, as an option. It needs its own provider key or its free model; it doesn't use your Claude subscription. To sign in: `docker compose exec -w /home/node workshop opencode auth login`.

### A5. Run the check

```bash
bash ~/Projects/qcon-workshop/workshop-setup/check.sh
```

It takes about a minute. It prints one line per check, then a summary block. Send us the summary block.

What the check does:

- On the laptop it reads Docker's version and memory, your free disk space, and the state of the two clones.
- In the container it compiles the sandbox without the network, starts PetClinic, tests it on `http://localhost:8080`, and stops it again. This writes build output to `petclinic/target`, which git ignores.
- It asks Claude for one word, to prove that your sign-in works. This is one small request on your plan or account. `--no-model` skips it.

It doesn't print keys, tokens or environment variables, and it shows your home folder as `~`.

### A6. Stop the container

Your sign-in and the downloaded image stay.

```bash
docker compose down
```

### Option A on the day

```bash
cd ~/Projects/qcon-workshop/workshop-setup
docker compose up -d
docker compose exec workshop claude          # Claude Code, in the sandbox
docker compose exec workshop bash            # a shell in the container
```

To see PetClinic, start it yourself in a shell in the container. The check stops it again when it finishes.

```bash
./mvnw spring-boot:run
```

Wait for the line `Started PetClinicApplication`, then open `http://localhost:8080` in your laptop's browser. The sandbox's files are in `~/Projects/qcon-workshop/petclinic`, so you can read them in your own editor.

## Option B: GitHub Codespaces

You need a personal GitHub account. An account managed by your employer may not be able to start a codespace on our repository. The free plan includes enough hours for the workshop, unless you have used them up this month.

### B1. Create the codespace

Open <https://github.com/qcon-ai-native-development/petclinic>, then **Code**, **Codespaces**, **Create codespace on main**. It opens in a browser tab, with a terminal in the bottom panel.

### B2. Sign in to Claude Code

In the codespace's terminal, start Claude Code in the home folder with this command, exactly as written:

```bash
cd ~ && env -u BROWSER claude
```

Claude Code prints a link. Open it, approve, copy the code the page shows, and paste it into the terminal. Then leave with `/exit`.

The `env -u BROWSER` part matters. Without it, a codespace opens a browser tab for the sign-in, and that tab ends on a "localhost" error.

**OpenCode** is in the container too, as an option. It needs its own provider key or its free model; it doesn't use your Claude subscription. To sign in: `cd ~ && opencode auth login`.

### B3. Run the check

```bash
cd /workspaces/petclinic && he-check
```

It takes about a minute. It prints one line per check, then a summary block. Send us the summary block.

The check compiles the sandbox without the network, starts PetClinic, tests it, and stops it again. It asks Claude for one word, to prove that your sign-in works. It doesn't print keys, tokens or environment variables.

### B4. Stop the codespace

Stop it from <https://github.com/codespaces>, so it doesn't use up your hours. Don't delete it: you start the same one again on the day.

### Option B on the day

Start the same codespace again from <https://github.com/codespaces> and work in its terminal. `claude` starts Claude Code in the sandbox.

To see PetClinic, start it yourself. The check stops it again when it finishes.

```bash
./mvnw spring-boot:run
```

Wait for the line `Started PetClinicApplication`. Then open the **Ports** tab in the bottom panel, find port 8080, and click the globe icon beside its address. A 502 error on that page means PetClinic isn't running yet.

## Both options: leave the sandbox alone until the workshop

Please don't open the sandbox in a coding agent, or ask an agent about it, before the day. The first exercise starts from a fresh look at it.

## If a check fails

Send us the summary block and the failing line anyway, and we'll help. The most common causes:

| Check | Option | Likely cause | What to do |
|---|---|---|---|
| `docker` fails | A | Docker isn't installed, or isn't started | Step A1. Start Docker Desktop, OrbStack or Colima, then run the check again |
| `docker-memory` warns | A | Docker has less than 4 GB | Raise the memory in Docker's settings. Colima: `colima stop && colima start --memory 6` |
| `image` fails | A | The image isn't downloaded | Step A3 |
| `sandbox` fails | A | The sandbox isn't cloned, or is on another commit | Step A2, or see "Updates" below |
| `container` fails | A | The container isn't running | `docker compose up -d` |
| `build` fails | A | The container can't write to the sandbox | See "Linux with another user id" below. On macOS or Windows, send us the line |
| `port` fails | A | Another program uses port 8080 | See "Port 8080 is taken" below |
| The sign-in ends on a "localhost" error page | B | A browser tab opened by itself | Close the tab and sign in with `cd ~ && env -u BROWSER claude` |
| PetClinic's page shows a 502 error | B | PetClinic isn't running | Start it with `./mvnw spring-boot:run` and reload the page |
| `claude-model` fails | A, B | Not signed in, or no access to a model | Step A4 or B2. If you signed in and it still fails, send us the line |
| `network` fails | A, B | A company proxy or firewall blocks `api.anthropic.com` | Try another network, such as your phone's hotspot, and tell us |

If something can't be fixed before the day, come anyway, and come 20 minutes early.

### Linux with another user id

On Linux without Docker Desktop, the container works as user id 1000. If `id -u` prints another number, the container can't write to your clone. Either use option B, or hand the clone to user id 1000 and read it without editing it from the laptop:

```bash
sudo chown -R 1000:1000 ~/Projects/qcon-workshop/petclinic
git config --global --add safe.directory ~/Projects/qcon-workshop/petclinic
```

### Port 8080 is taken

Choose another port, for the container and for the check:

```bash
export HE_APP_PORT=8081
docker compose up -d
bash check.sh
```

PetClinic is then on `http://localhost:8081`.

## Updates

We will change the sandbox before the workshop, and we'll email you when we do. These commands replace your copy of the sandbox with the current one. They discard any change you made in it.

Option A:

```bash
git -C ~/Projects/qcon-workshop/workshop-setup pull
git -C ~/Projects/qcon-workshop/petclinic fetch origin
git -C ~/Projects/qcon-workshop/petclinic reset --hard origin/main
cd ~/Projects/qcon-workshop/workshop-setup && docker compose pull && docker compose up -d
```

Option B, in the codespace's terminal:

```bash
git -C /workspaces/petclinic fetch origin
git -C /workspaces/petclinic reset --hard origin/main
```

Then run the check again. If the image changes too, the email will say how to rebuild a codespace.

## For the presenters

- `Dockerfile` and `image/he-check` make the image; `compose.yaml` names its tag. A new tag means a new image: change the tag in `compose.yaml` and in the sandbox's `devcontainer.json`, and CI builds and publishes it. A published tag is never overwritten.
- `check.sh` and the `Dockerfile` pin the sandbox's commit. `tests/pins-test.sh` fails when they differ.
- Tests: `bash tests/he-check-test.sh`, `bash tests/check-test.sh`, `bash tests/pins-test.sh`. They use stub commands and need no Docker.
- CI (`.github/workflows/setup.yml`) lints, runs the tests, builds the image on both architectures, follows option A's steps in the container, and publishes a new tag from `main`. It skips the model call, which needs a sign-in.
