# workshop-setup

Setup for the QCon San Francisco workshop "Effective AI-native Development with Harness Engineering", Friday 20 November 2026. Please do it before the day. Most of the time goes to one download.

When you have finished, run the check in step 5 and send us its summary.

The workshop runs in a container on your laptop. The container holds Claude Code, OpenCode, Java 17 and everything PetClinic needs to build, so you install none of those yourself. You install Docker.

If your laptop can't run Docker, use [GitHub Codespaces](#if-your-laptop-cant-run-docker-codespaces) instead. It runs the same container in your browser.

## What you need

- A laptop with macOS 13 or later, Linux, or Windows 10 or 11 with WSL 2.
- 8 GB of memory and 10 GB of free disk space.
- Docker, with at least 4 GB of memory given to it.
- A Claude subscription (Pro, Max, Team or Enterprise) or an Anthropic Console account. A Pro plan may reach its usage limit during the day; Max or a Console account is the safer choice.

On Windows, install Ubuntu with `wsl --install` in PowerShell, then do every step below in the Ubuntu terminal. Keep the workshop folders in your Linux home folder (`~/workshop`). Folders under `/mnt/c` are slow from WSL. PowerShell and CMD aren't supported.

## 1. Docker

Any of these works:

- macOS: [Docker Desktop](https://docs.docker.com/desktop/), [OrbStack](https://orbstack.dev) or [Colima](https://github.com/abiosoft/colima).
- Windows: Docker Desktop with its WSL 2 backend, and WSL integration switched on for your Ubuntu distribution.
- Linux: [Docker Engine](https://docs.docker.com/engine/install/) with the Compose plugin.

If your employer manages your laptop, check its rules for Docker Desktop first.

Then check that Docker runs and has Compose:

```bash
docker compose version
```

You also need git. macOS: `xcode-select --install`. Ubuntu and WSL: `sudo apt-get install -y git curl`.

## 2. Clone the two repositories

Use exactly these paths. The container expects the two folders side by side.

```bash
mkdir -p ~/workshop
git clone https://github.com/qcon-ai-native-development/workshop-setup.git ~/workshop/workshop-setup
git clone https://github.com/qcon-ai-native-development/petclinic.git ~/workshop/petclinic
```

`petclinic` is the sandbox: the application we work on in the workshop.

## 3. Download the image and start the container

```bash
cd ~/workshop/workshop-setup
docker compose pull
docker compose up -d
```

The download is about 0.7 GB, and the image takes about 1.5 GB of disk. Download it at home; the venue's network is shared by everyone in the room.

Every `docker compose` command in this file runs from `~/workshop/workshop-setup`.

## 4. Sign in to Claude Code

```bash
docker compose exec -w /home/node workshop claude
```

Claude Code starts in the container and asks how you want to sign in. It prints a link. Open the link in your laptop's browser, approve, and paste the code back into the terminal. Then leave with `/exit`.

The sign-in is kept in a Docker volume, so you do this once. It stays on your laptop.

The command starts Claude Code in the container's home folder, away from the sandbox. Please keep it that way until the workshop (step 6).

**OpenCode** is in the container too, as an option. It needs its own provider key or its free model; it doesn't use your Claude subscription. To sign in: `docker compose exec -w /home/node workshop opencode auth login`.

## 5. Run the check

```bash
bash ~/workshop/workshop-setup/check.sh
```

It takes about a minute. It prints one line per check, then a summary block. Send us the summary block by replying to the email that brought you here.

What the check does:

- On the laptop it reads Docker's version and memory, your free disk space, and the state of the two clones.
- In the container it compiles the sandbox without the network, starts PetClinic, tests it on `http://localhost:8080`, and stops it again. This writes build output to `petclinic/target`, which git ignores.
- It asks Claude for one word, to prove that your sign-in works. This is one small request on your plan or account. `--no-model` skips it.

It doesn't print keys, tokens or environment variables, and it shows your home folder as `~`.

## 6. Leave the sandbox alone until the workshop

Please don't open the sandbox in a coding agent, or ask an agent about it, before the day. The first exercise starts from a fresh look at it.

When you're done, stop the container. Your sign-in and the downloaded image stay.

```bash
docker compose down
```

## On the day

```bash
cd ~/workshop/workshop-setup
docker compose up -d
docker compose exec workshop claude          # Claude Code, in the sandbox
docker compose exec workshop bash            # a shell in the container
```

To run PetClinic, in a shell in the container:

```bash
./mvnw spring-boot:run
```

Then open `http://localhost:8080` in your laptop's browser. The sandbox's files are in `~/workshop/petclinic`, so you can read them in your own editor.

## If your laptop can't run Docker: Codespaces

You need a personal GitHub account. An account managed by your employer may not be able to start a codespace on our repository. The free plan includes enough hours for the workshop, unless you have used them up this month.

1. Open <https://github.com/qcon-ai-native-development/petclinic>, then **Code**, **Codespaces**, **Create codespace on main**.
2. In the codespace's terminal, sign in. Start Claude Code in the home folder, follow the link it prints, then leave with `/exit`:

   ```bash
   cd ~ && claude
   ```

3. Run the check from the sandbox folder and send us its summary block:

   ```bash
   cd /workspaces/petclinic && he-check
   ```

4. Stop the codespace from <https://github.com/codespaces> so it doesn't use up your hours. Start the same one again on the day; don't delete it.

## If a check fails

Send us the summary block and the failing line anyway, and we'll help. The most common causes:

| Check | Likely cause | What to do |
|---|---|---|
| `docker` fails | Docker isn't installed, or isn't started | Step 1. Start Docker Desktop, OrbStack or Colima, then run the check again |
| `docker-memory` warns | Docker has less than 4 GB | Raise the memory in Docker's settings. Colima: `colima stop && colima start --memory 6` |
| `image` fails | The image isn't downloaded | Step 3 |
| `sandbox` fails | The sandbox isn't cloned, or is on another commit | Step 2, or `git -C ~/workshop/petclinic pull` |
| `container` fails | The container isn't running | `docker compose up -d` |
| `build` fails | The container can't write to the sandbox | See "Linux with another user id" below. On macOS or Windows, send us the line |
| `claude-model` fails | Not signed in, or no access to a model | Step 4. If you signed in and it still fails, send us the line |
| `network` fails | A company proxy or firewall blocks `api.anthropic.com` | Try another network, such as your phone's hotspot, and tell us |
| `port` fails | Another program uses port 8080 | See "Port 8080 is taken" below |

If something can't be fixed before the day, come anyway, and come 20 minutes early.

### Linux with another user id

On Linux without Docker Desktop, the container works as user id 1000. If `id -u` prints another number, the container can't write to your clone. Either use the Codespaces path, or hand the clone to user id 1000 and read it without editing it from the laptop:

```bash
sudo chown -R 1000:1000 ~/workshop/petclinic
git config --global --add safe.directory ~/workshop/petclinic
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

We may change these repositories before the workshop. To get the changes:

```bash
git -C ~/workshop/workshop-setup pull
git -C ~/workshop/petclinic pull
cd ~/workshop/workshop-setup && docker compose pull && docker compose up -d
```

Then run the check again.

## For the presenters

- `Dockerfile` and `image/he-check` make the image; `compose.yaml` names its tag. A new tag means a new image: change the tag in `compose.yaml` and in the sandbox's `devcontainer.json`, and CI builds and publishes it. A published tag is never overwritten.
- `check.sh` and the `Dockerfile` pin the sandbox's commit. `tests/pins-test.sh` fails when they differ.
- Tests: `bash tests/he-check-test.sh`, `bash tests/check-test.sh`, `bash tests/pins-test.sh`. They use stub commands and need no Docker.
- CI (`.github/workflows/setup.yml`) lints, runs the tests, builds the image on both architectures, follows this README's steps in the container, and publishes a new tag from `main`. It skips the model call, which needs a sign-in.
