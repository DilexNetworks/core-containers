# Architecture

This document describes the architectural principles and image layering strategy used in the **core-containers** repository.

The intent is to make the system:

- Predictable
- Reproducible
- Easy to reason about
- Easy to extend without unintended side effects

---

## High-level goals

1. **Single source of truth** for build and deployment toolchains
2. **Clear image layering**, so dependencies are explicit
3. **Pinned versions** everywhere that matters
4. **CI and local parity** (the same images power both)
5. **Minimal base images**, extended only where necessary

---

## Image layering model

The images in this repository form a deliberate dependency tree:

```
ci-base
├── python
│   └── work
├── hugo
├── aws-cli
│   └── cdk
└── latex (standalone, manual build)
```

Each image has a *single responsibility* and only adds what it strictly needs.

---

## Base image: `ci-base`

`ci-base` is the foundation for all other images.

### What belongs here

Only tools that are:

- universally useful
- extremely stable
- unlikely to cause dependency conflicts

Currently included:

- Alpine Linux (pinned version)
- `bash`
- `ca-certificates`
- `git`
- `openssh-client`
- `tar` (full tar, not BusyBox)

### What does *not* belong here

- Language runtimes (Node, Python, Go)
- Cloud SDKs
- Application binaries
- Compatibility shims unless broadly required

The guiding rule is: **if it’s not needed by *most* images, it doesn’t go here**.

---

## Python image: `python`

The `python` image provides the shared Python runtime used by Python-based tools.

### Included tooling

- Python 3
- `pip`
- `virtualenv`
- A dedicated virtual environment at `/opt/venv`

### Inheritance

- Inherits common command-line tooling from `ci-base`
- Provides the base for Python applications such as `work`

Keeping the Python runtime in its own image avoids adding a language runtime to every container while still allowing Python-based tools to share a consistent foundation.

---

## Work image: `work`

The `work` image packages the `core-work` command-line application as a Docker-backed development tool.

### Included tooling

- The pinned `core-work` release
- Python and the virtual environment inherited from `python`
- Git and OpenSSH inherited from `ci-base`

### Inheritance

- Inherits from `python`
- Uses `ci-base` indirectly through the Python image

The image contains the application and its runtime. Integration with the host working directory, Git configuration, and SSH agent is handled by the installed `work` wrapper.

---

## Hugo image: `hugo`

The `hugo` image is designed specifically for building static sites and documentation.

### Key design decisions

#### Upstream binaries

Hugo is installed from **official upstream release binaries**, not Alpine packages.

Reasons:
- Faster access to new Hugo releases
- Exact version pinning
- Avoidance of Alpine packaging delays or revisions (`-r1`, `-r2`, etc.)

#### Alpine compatibility

Because upstream Hugo binaries are built against glibc, the image includes:

- `gcompat`
- `libstdc++`
- `libgcc`

This allows glibc-linked binaries to run correctly on Alpine (musl).

#### Dart Sass

Dart Sass is installed as the **standalone CLI distribution**, not via `npm`:

- No Node.js dependency
- Predictable behavior
- Matches Hugo’s expectations

The full Dart Sass directory is preserved and symlinked to ensure the bundled runtime works correctly.

---

## AWS CLI image: `aws-cli`

The `aws-cli` image provides a pinned AWS CLI toolchain for both local usage and CI.

### Why this is a separate image

Many build workflows (e.g. Hugo documentation builds) do not require AWS access. Keeping AWS tooling isolated:

- Reduces attack surface
- Keeps build images lightweight
- Avoids pulling AWS tooling into environments that don’t need it

### Additions

- AWS CLI v2 (pinned via Alpine package version)

This image is used for:

- `aws s3 sync`
- CloudFront invalidations
- Deployment automation

It is also used as a shared base for other images that require the AWS CLI (e.g. `cdk`).

---

## CDK image: `cdk`

The `cdk` image is used for AWS infrastructure deployments.

### Included tooling

- Node.js
- npm
- AWS CDK

### Inheritance

- Inherits AWS CLI from `aws-cli`
- Does *not* inherit from `hugo`

This avoids unnecessary coupling between site-building tools and infrastructure tooling.

---

## LaTeX image: `latex`

The LaTeX image is a standalone build environment.

### Characteristics

- Large image
- Long build time
- Specialized use cases

For these reasons:

- It is typically built separately (e.g. via workflow dispatch) when needed

This keeps the primary pipeline fast and reliable.

---

## Build ordering and CI strategy

Image dependencies are respected explicitly in CI:

1. `ci-base`
2. `python`, `hugo`, and `aws-cli`
3. `work` (depends on `python`) and `cdk` (depends on `aws-cli`)

This prevents race conditions where a derived image is built before its base image is published.

LaTeX may be built separately depending on needs.

---

## Local vs CI builds

Local builds are optimized for speed and iteration:

- Single-arch by default
- Tagged as `:local`
- Never pushed

CI builds:

- Multi-arch (`amd64`, `arm64`)
- Published to Docker Hub
- Fully reproducible from source

Both paths use the **same Dockerfiles**.

---

## Wrapper-based execution model

Instead of installing tools locally, lightweight shell wrappers are installed into `~/bin`.

These wrappers:

- Invoke the appropriate Docker image
- Mount the current working directory at `/work`
- Set the container working directory to `/work`
- Set `HOME=/tmp` for ephemeral container state
- Mount the host Git configuration read-only when available
- Forward the host SSH agent when available
- Forward command-line arguments transparently

This ensures:

- Clean local machines
- Consistent behavior across environments
- Easy upgrades by pulling new images
- No private SSH keys copied or mounted into containers

### Git and SSH integration

Git operations over SSH use agent forwarding rather than mounting the host `~/.ssh` directory.

The wrapper mounts the host SSH agent socket and exposes it through `SSH_AUTH_SOCK` inside the container. Authentication therefore remains on the host, and private key files are never made available to the container.

GitHub remotes normally include the SSH user explicitly:

```text
git@github.com:DilexNetworks/core-containers.git
```

Because the remote URL already specifies `git` as the user, the container does not require the host SSH configuration merely to provide `User git`.

Host-key state is written to an ephemeral file inside the container. The wrapper configures SSH with a temporary `UserKnownHostsFile` and `StrictHostKeyChecking=accept-new`.

This avoids:

- Mounting the complete host `~/.ssh` directory
- Giving the container access to private key files
- Making the host `known_hosts` file writable

### Container user model

The wrappers intentionally do not force containers to run with the host macOS UID and GID.

Passing a macOS UID such as `501` into an Alpine container may leave the process without a corresponding passwd entry. OpenSSH relies on that user lookup and can fail with:

```text
No user exists for uid 501
```

The containers therefore run as their image-defined user. Docker Desktop mediates bind-mounted file access on macOS, so explicit host UID/GID preservation is unnecessary for this workflow.

---

## Future extensions

This architecture is intentionally conservative and extensible.

Expected future additions include:

- Shared `skel` repositories that reference these images
- Additional narrowly-scoped images (e.g. `node-build`, `python-build`)
- Versioned base variants if compatibility needs diverge

Any extension should preserve the core principles:

> *Clear responsibility, minimal coupling, explicit dependencies.*