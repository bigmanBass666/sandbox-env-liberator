# Domain 6: Development Toolchain

**Pre-installed Runtimes** (via mise):
- Node.js v24.15.0, Python 3.14.4, Go 1.25.1, Java 25.0.2
- Ruby 3.4.4, PHP 8.5.6, Rust 1.92.0, Swift 6.2.4
- Elixir 1.18.3, Erlang OTP 27, Bun 1.2.14

**Pre-installed Build Tools**:
- make, cmake, gradle, maven, bazel

**Pre-installed Dev Tools**:
- git, SQLite3, SSH, gcc/g++, tar/gzip/zip

**Missing but Installable** (via setup-dev-toolchain.sh):
- screen/tmux: `apt-get install -y screen tmux`
- webpack/vite/esbuild: `npm install -g webpack vite esbuild`
- Python packages: `pip install --user virtualenv httpx requests`
- Go tools: `go install golang.org/x/tools/gopls@latest`

**Not Available** (kernel/container restrictions):
- Docker/Podman: No kernel access
- Cloud CLIs: Download binaries manually
- PostgreSQL/Redis: `apt-get install` if needed
