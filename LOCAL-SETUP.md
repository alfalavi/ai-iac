# Local Setup (Without Codespaces)

If you are not using GitHub Codespaces or a Dev Container, follow these steps to prepare your local machine before starting the lab.

---

## Prerequisites

### Required Tools

| Tool                  | Version                     | Install                                                                                         |
| --------------------- | --------------------------- | ----------------------------------------------------------------------------------------------- |
| **Node.js**           | 20.x (LTS)                  | [nodejs.org](https://nodejs.org) or `nvm install 20`                                            |
| **npm**               | 10.x (bundled with Node 20) | Comes with Node                                                                                 |
| **Terraform**         | 1.7+                        | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)  |
| **tflint**            | v0.50.3 (pinned — see note) | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint/releases/tag/v0.50.3) |
| **Checkov**           | latest                      | `pip3 install checkov`                                                                          |
| **Python 3**          | 3.10+                       | [python.org](https://www.python.org/downloads/)                                                 |
| **Git**               | 2.x+                        | [git-scm.com](https://git-scm.com/downloads)                                                    |
| **GitHub CLI (`gh`)** | 2.x+                        | [cli.github.com](https://cli.github.com)                                                        |

### Required Accounts & Access

- **GitHub account** with access to the bootcamp template repository
- **GitHub Copilot** license (individual, business, or enterprise) — Copilot Agent mode must be enabled
- **VS Code** (recommended) with the extensions listed below

---

## VS Code Extensions

Install these from the Extensions panel (`Ctrl+Shift+X` / `Cmd+Shift+X`) or run the commands below:

```bash
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat
code --install-extension hashicorp.terraform
code --install-extension esbenp.prettier-vscode
code --install-extension dbaeumer.vscode-eslint
```

After installing, open VS Code Settings and confirm:

- `github.copilot.chat.agent.enabled` is `true`
- `editor.formatOnSave` is `true`

---

## Step-by-Step Setup

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
```

### 2. Install Node dependencies

```bash
npm install
```

This installs dependencies for both `packages/frontend` and `packages/backend` via npm workspaces.

### 3. Install Python tooling (Checkov)

```bash
pip3 install checkov
```

Verify:

```bash
checkov --version
```

### 4. Install Terraform

Follow the official guide for your OS: <https://developer.hashicorp.com/terraform/install>

Verify:

```bash
terraform -version
```

### 5. Install tflint

> **Note:** TFLint v0.51.0+ embeds Terraform v1.6+ internals and falls under HashiCorp's BUSL 1.1 license, which caused the Homebrew formula to be removed. Install **v0.50.3** (the last MPL-2.0 release) using the methods below.

**macOS (direct download — Homebrew formula is unavailable):**

```bash
curl -Lo /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/v0.50.3/tflint_darwin_arm64.zip
unzip -o /tmp/tflint.zip -d /tmp/tflint-bin
sudo install /tmp/tflint-bin/tflint /usr/local/bin/tflint
```

> Apple Silicon Macs (M1/M2/M3/M4) should use `darwin_arm64` (shown above). On older Intel Macs, replace `darwin_arm64` with `darwin_amd64`.

**Linux (curl — pins to v0.50.3):**

```bash
curl -Lo /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/v0.50.3/tflint_linux_amd64.zip
unzip -o /tmp/tflint.zip -d /tmp/tflint-bin
sudo install /tmp/tflint-bin/tflint /usr/local/bin/tflint
```

**Windows (PowerShell — pins to v0.50.3):**

```powershell
Invoke-WebRequest -Uri "https://github.com/terraform-linters/tflint/releases/download/v0.50.3/tflint_windows_amd64.zip" -OutFile "$env:TEMP\tflint.zip"
Expand-Archive -Path "$env:TEMP\tflint.zip" -DestinationPath "$env:TEMP\tflint-bin" -Force
Move-Item "$env:TEMP\tflint-bin\tflint.exe" "C:\Windows\System32\tflint.exe"
```

Verify:

```bash
tflint --version
```

### 6. Install & authenticate GitHub CLI

```bash
# Install (macOS)
brew install gh

# Authenticate
gh auth login
```

Follow the prompts to log in with your GitHub account.

### 7. Verify everything is working

```bash
node --version       # v20.x.x
npm --version        # 10.x.x
terraform -version   # Terraform v1.x.x
tflint --version     # tflint version x.x.x
checkov --version    # checkov x.x.x
gh --version         # gh version x.x.x
```

### 8. Start the app (optional sanity check)

```bash
npm start
```

- Backend API: <http://localhost:4000>
- Frontend UI: <http://localhost:3000>

---

## Port Forwarding

The app uses these ports locally. Make sure nothing else is bound to them:

| Service           | Port |
| ----------------- | ---- |
| Frontend (React)  | 3000 |
| Backend (Express) | 4000 |

---

## Troubleshooting

| Issue | Fix |
| ----- | --- |
| `npm install` fails with peer dependency errors | Run `npm install --legacy-peer-deps` |
| `checkov` not found after install | Ensure `~/.local/bin` (Linux) or the Python `bin` dir is on your `PATH` |
| `tflint` not found | Add the install directory to your `PATH` |
| Copilot Agent mode not available | Confirm your Copilot plan includes Agent mode and the extension is updated to the latest version |
| Port already in use | macOS/Linux: `lsof -ti:<port> \| xargs kill` — Windows: check Task Manager |

---

> **Tip:** If you run into environment issues, the fastest path is to use [GitHub Codespaces](https://github.com/features/codespaces) — the Dev Container in this repo provisions everything automatically.

<div align="center"><img src="image.png" width="48" alt="Session PE banner" /></div>
