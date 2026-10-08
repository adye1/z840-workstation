#!/usr/bin/env bash
# AI governance + security toolchain in isolated venvs (run as your normal user, NOT sudo).
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run WITHOUT sudo"; exit 1; }
LAB="${LAB:-$HOME/ai-governance-lab}"; mkdir -p "$LAB"/{tools,reports,evidence}
cd "$LAB"
# Separate venvs: garak and pyrit pin large, conflict-prone dependency trees.
uv venv tools/garak-venv --python 3.12
uv pip install --python tools/garak-venv/bin/python garak
uv venv tools/lab-venv --python 3.12
uv pip install --python tools/lab-venv/bin/python pyrit presidio-analyzer presidio-anonymizer llm-guard picklescan jupyterlab pandas
command -v npx &>/dev/null || sudo apt-get install -y nodejs npm
echo "Smoke test (local model, no data leaves the box):"
echo "  tools/garak-venv/bin/garak --model_type ollama --model_name llama3.1:8b --probes promptinject,leakreplay"
echo "  npx promptfoo@latest init"
