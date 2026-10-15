# 👨‍💻👩‍💻 [_LetsMarkdown.com_](https://LetsMarkdown.com/)

Fast, minimal web editor that makes markdown editing **collaborative** and
**accessible** to everyone.

<p align="center">
<a href="https://LetsMarkdown.com/">
<img src="./public/static/lmd_demo.gif" width="800"><br>
<strong>LetsMarkdown.com</strong>
</a>
</p>

## Motivation

\> I want to edit markdown files with my friends, but sending/resending files,
changing viewing access, version control, and previewing are just _too much
work_.

\> 💡 why not create a google doc for collaborative markdown editing,
**_without_** having to log into Google, change view/edit access, worry about
previewing the file, etc?

\> Voilà, after hours of <del>laborious</del> coding,
[LetsMarkdown.com](https://LetsMarkdown.com/) is born!

## Features

- **Live** collaborative markdown editing and preview
- **VSCode-like** editor with support for command palette (syntax highlighting,
  autocomplete, editor themes...)
- Minimal setup with **no login required** - say goodbye to malicious trackers
  and privacy invasions
- Efficient backend built with **Rust** and **WebAssembly**
- Dark mode (duh)
- **Emoji** support with shortcuts enabled
- (Upcoming) cursors tracking, synced scrolling, subscript/footnote/insert
  support, and more

## Tech Stack

- Frontend: React.js (TypeSript), Vite.js, Chakra UI
  - Editor & markdown preview: Monaco, mardown-it.js, highlight.js
- Backend: Rust, WebAssembly, Node.js
- Deployment & hosting: Docker, DigitalOcean
- CI/CD: Github Action
- Formatting: Prettier, Rustfmt
- Design & prototyping: Figma

## Development Info

This application is built using a backend
[operational transformation](https://docs.rs/operational-transform/latest/operational_transform/)
control server written in Rust (based on
[Rustpad](https://github.com/ekzhang/rustpad)), and a frontend written in
TypeScript using [React.js](https://reactjs.org/).

The backend server supports real-time collaborative editing sessions, and the
frontend offers a collaborative text editor with built-in markdown syntax
highlighting and auto-completion. These parts of the application are connected
via WebSocket communication.

For markdown previewing, I used the
[markdown-it.js](https://markdown-it.github.io/) library to dynamically render
the markdown file. To style the markdown file, I also created a custom
`markdown.css` stylesheet.

To develop this application locally, you need to:

First, install `Rust`, `wasm-pack`, and `Node.js`. Verify your installation
with:

```bash
rustup -V && wasm-pack -V && npm -v
```

Then, build the WebAssembly part of the app:

```bash
wasm-pack build --target web letsmarkdown-wasm
```

After that, install the dependencies for the React application:

```
npm install
```

Next, you can compile and run the backend web server:

```bash
cargo run
```

While the backend is running, open another shell and run the following command
to start the frontend dev server.

```bash
npm run dev
```

This command will open a browser window to `http://localhost:3000`, with hot
reloading enabled on saved changes.

## Deployment

[LetsMarkdown.com](https://LetsMarkdown.com/) is distributed as a single 12 MB
Docker image, which is built automatically from the `Dockerfile` in this
repository. You can pull the latest version of this image from Docker Hub. It
has multi-platform support for linux/amd64 and linux/arm64.

```
docker pull cveinnt/letsmarkdown
```

(You can also manually build this image with `docker build -t rustpad .` in the
project root directory.) To run locally, execute the following command, then
open `http://localhost:3030` in your browser.

```
docker run --rm -dp 3030:3030 cveinnt/letsmarkdown
```

I deploy a public instance of this image with
[DigitalOcean App Platform](https://www.digitalocean.com/products/app-platform/).

### Automatic deployment from GHCR

For this repository, each push to `main` builds and publishes
`ghcr.io/<owner>/<repository>:latest` for linux/amd64 and linux/arm64. Once the
build and formatting checks pass and the image is published, the
`Deploy production` job connects to your server over SSH and replaces its Docker
container. Pull requests never deploy or access production secrets.

The deployment pulls the commit tag published alongside `latest`, so it runs the
exact image that passed this workflow even if `latest` changes later. It pulls
before stopping the old container, checks `/api/stats` after startup, and
restores the previous container if startup fails. Deployments are serialized,
and newer pushes do not cancel an active replacement.

**Deployment restarts disconnect WebSocket clients and clear documents held in
server memory. Restoring a container restores its image and configuration, not
its previous in-memory documents.** There is a short interruption during
container replacement.

#### Server and registry setup

- The server must be reachable from GitHub-hosted runners over SSH and have
  Bash, Docker, and curl installed. The SSH user must be able to run
  `docker info` without an interactive privilege prompt.
- Add the deployment SSH public key to that user's `~/.ssh/authorized_keys`. Use
  a dedicated key without a passphrase for automation. Generate one on a trusted
  machine with `ssh-keygen -t ed25519 -f ./letsmarkdown-deploy -N ''`; install
  `letsmarkdown-deploy.pub` on the server and use the private key as the secret
  below. Keep the private key outside this repository.
- In the GHCR package settings, change the package visibility to **Public**. A
  public source repository does not automatically make a newly published package
  public. This deployment pulls anonymously, so no GHCR token or PAT needs to be
  added. See the
  [GitHub Container registry documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
- The container publishes to `127.0.0.1:3030` by default, so the host port is
  accessible only from the server. For public access, configure a reverse proxy
  running on the host to forward to `http://127.0.0.1:3030` (or the configured
  host port), including WebSocket support. A reverse proxy in another container
  needs a shared Docker network instead of its own loopback address. An existing
  container with a different name must be stopped or migrated before the first
  deployment if it occupies that port. The script manages only the selected
  container name and does not inherit custom volumes, networks, or environment
  variables from an existing container.

#### GitHub secrets and variables

Create an environment named `production` under repository **Settings →
Environments** and restrict its deployment branches to `main`. Add these
**Environment secrets**:

| Secret               | Value                                                             |
| -------------------- | ----------------------------------------------------------------- |
| `DEPLOY_HOST`        | Server IP address or hostname, without `ssh://` or a port.        |
| `DEPLOY_USER`        | SSH login username that can run Docker.                           |
| `DEPLOY_SSH_KEY`     | Complete private key, including its header, footer, and newlines. |
| `DEPLOY_KNOWN_HOSTS` | Verified SSH host key entries in OpenSSH `known_hosts` format.    |

Obtain the host key entries from a trusted machine with
`ssh-keyscan -H -p 22 YOUR_SERVER`. Verify their fingerprints against the
server's host keys through a trusted connection before saving the output. For
example, view the server's Ed25519 fingerprint with
`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server. Use your
actual SSH port in the scan; nonstandard ports use `[host]:port` entries.

Optionally add these **Environment variables** (not secrets) in `production`:

| Variable           | Default        | Meaning                                 |
| ------------------ | -------------- | --------------------------------------- |
| `DEPLOY_SSH_PORT`  | `22`           | Server SSH port.                        |
| `DEPLOY_PORT`      | `3030`         | Loopback host port mapped to port 3030. |
| `DEPLOY_CONTAINER` | `letsmarkdown` | Managed Docker container name.          |

After setup, push to `main` to deploy. To retry a failed deployment, rerun the
failed job in Actions. On success, the old container is removed; old images are
retained and unrelated containers and images are not pruned. If a deployment is
forcibly terminated and leaves `<container>-previous`, inspect and recover that
container before retrying; the script refuses to overwrite it.

## Contributing

This project is still in a **very early** phase. If you're interested in adding
new features or fixing bugs, please reach out to me by creating a GitHub issue!

I plan to integrate this repository continuously, and the code base already
accounts for things like code style (Prettier, Rustfmt) and build success
(Docker). The current state of the `main` branch is continuously deployed to the
production web server at [LetsMarkdown.com](https://LetsMarkdown.com/).

## Credits

[LetsMarkdown.com](https://LetsMarkdown.com/) is inspired by
[composing.studio](https://composing.studio/), which is based on
[Rustpad](https://github.com/ekzhang/rustpad).

<br>

<sup>
All code is licensed under the <a href="LICENSE">MIT license</a>.
</sup>
