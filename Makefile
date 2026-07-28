# Notebook QA — local runner
# Mirrors the checks performed by the CI workflow in .github/workflows/qa.yml.
#
# Quick start:
#   make qa-install        # install QA tools into the current Python environment
#   make qa                # run all static checks
#   make qa NOTEBOOKS=template-notebook.ipynb  # limit to one notebook
#
# Checks NOT available locally (CI only):
#   links        — requires the lychee Rust binary
#   accessibility — requires the jupyterlab-a11y-checker GitHub Action
#   execute       — runs notebooks end-to-end (use your own conda env)

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

QA_TOOLS   := .qa-tools
CHECKERS   := $(QA_TOOLS)/process-notebooks/checkers
QA_CONFIG  := .github/notebook-qa.yml
QA_TOOLS_REPO := https://github.com/ecmwf-training/reusable-workflows

TEMPLATE_REPO   := https://github.com/ecmwf-training/jupyterbook-submodule-template
TEMPLATE_REMOTE := template
TEMPLATE_BRANCH := develop
TEMPLATE_PATHS  := .github Makefile setup.cfg README.md

NOTEBOOKS  ?= $(shell find . -name "*.ipynb" \
                  -not -path "*/.ipynb_checkpoints/*" \
                  -not -path "*/$(QA_TOOLS)/*" \
                  -not -path "*/_build/*" \
				  )

# ---------------------------------------------------------------------------
# Default target
# ---------------------------------------------------------------------------

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Environment setup targets
# ---------------------------------------------------------------------------

.PHONY: conda-env-update
conda-env-update:
	conda install "jupyter-book>=2,<3" && conda env update -f environment.yml

.PHONY: uv-env-update
uv-env-update:
	uv pip install "jupyter-book>=2,<3" && uv pip install pip &&  uv pip install -r requirements.txt

# ---------------------------------------------------------------------------
# Template sync (for repositories created from this template)
# ---------------------------------------------------------------------------

.PHONY: template-update
template-update: ## Sync core components (.github/, Makefile, setup.cfg) from the upstream template
	@if git remote get-url $(TEMPLATE_REMOTE) > /dev/null 2>&1; then \
	  git remote set-url $(TEMPLATE_REMOTE) $(TEMPLATE_REPO); \
	else \
	  git remote add $(TEMPLATE_REMOTE) $(TEMPLATE_REPO); \
	fi
	git fetch $(TEMPLATE_REMOTE) $(TEMPLATE_BRANCH)
	git checkout $(TEMPLATE_REMOTE)/$(TEMPLATE_BRANCH) -- $(TEMPLATE_PATHS)
	git reset
	@echo ""
	@echo "Core components updated from template. Review changes with: git diff HEAD"
	@echo "Commit when satisfied:  git add $(TEMPLATE_PATHS) && git commit -m 'chore: sync core components from template'"

# ---------------------------------------------------------------------------
# Jupyter Book targets
# ---------------------------------------------------------------------------

jupyter-book:
	jupyter book clean -y && jupyter book build && jupyter book start


# ---------------------------------------------------------------------------
# Tool setup
# ---------------------------------------------------------------------------

$(QA_TOOLS):
	git clone --depth=1 $(QA_TOOLS_REPO) $(QA_TOOLS)

.PHONY: qa-tools
qa-tools: $(QA_TOOLS) ## Clone the QA tools repository (skipped if already present)

.PHONY: qa-tools-update
qa-tools-update: ## Update the QA tools repository to the latest main
	cd $(QA_TOOLS) && git pull --ff-only

.PHONY: qa-install
qa-install: $(QA_TOOLS) ## Install QA dependencies into the active Python environment
	cd $(QA_TOOLS) && python -m pip install .

# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

.PHONY: qa-lint
qa-lint: ## (2.2.3) Lint code cells with ruff check
	ruff check $(NOTEBOOKS)

.PHONY: qa-format
qa-format: ## (2.2.3) Check code-cell formatting with ruff format
	ruff format --check --diff $(NOTEBOOKS)

.PHONY: qa-pynblint
qa-pynblint: $(QA_TOOLS) ## (2.2.3) Run pynblint on each notebook
	@PYNBLINT_EXCLUDE=$$(PYTHONPATH=$(CHECKERS) python -c \
	  "from qa_config import get_pynblint_exclude, load_config; \
	   print(get_pynblint_exclude(load_config('$(QA_CONFIG)')))"); \
	failed=0; \
	for nb in $(NOTEBOOKS); do \
	  echo "Checking: $$nb"; \
	  out=/tmp/pynblint_XXXXXX.json; \
	  rm -f "$$out"; \
	  mktemp -u "$$out" > /dev/null; \
	  if [ -n "$$PYNBLINT_EXCLUDE" ]; then \
	    pynblint "$$nb" -o "$$out" --exclude "$$PYNBLINT_EXCLUDE"; \
	  else \
	    pynblint "$$nb" -o "$$out"; \
	  fi; \
	  lint_count=$$(python -c "import json; print(len(json.load(open('$$out'))['lints']))"); \
	  if [ "$$lint_count" -gt 0 ]; then \
	    echo "❌ $$nb has $$lint_count pynblint issue(s):"; \
	    python -c "\
import json; \
data = json.load(open('$$out')); \
[print(f\"  - ({l['slug']}) {l['description']}\") for l in data['lints']]"; \
	    failed=1; \
	  else \
	    echo "✅ $$nb passed pynblint"; \
	  fi; \
	  rm -f "$$out"; \
	done; \
	exit $$failed

.PHONY: qa-figures
qa-figures: $(QA_TOOLS) ## (3.3.2) Check figure attribution in notebooks
	PYTHONPATH=$(CHECKERS) python $(CHECKERS)/figure_checker.py \
	  --config $(QA_CONFIG) $(NOTEBOOKS)

.PHONY: qa-metadata
qa-metadata: $(QA_TOOLS) ## (1.2.6) Check version metadata in notebooks
	PYTHONPATH=$(CHECKERS) python $(CHECKERS)/metadata_checker.py \
	  --config $(QA_CONFIG) $(NOTEBOOKS)

.PHONY: qa-data-source
qa-data-source: $(QA_TOOLS) ## (1.2.8) Check data source attribution (warning only)
	-PYTHONPATH=$(CHECKERS) python $(CHECKERS)/data_source_checker.py \
	  --config $(QA_CONFIG) $(NOTEBOOKS)

.PHONY: qa-license
qa-license: ## (1.2.4) Check that a non-empty LICENSE file exists
	@if [ -s LICENSE ]; then \
	  echo "✅ LICENSE file is present and non-empty"; \
	else \
	  echo "❌ LICENSE file is missing or empty"; exit 1; \
	fi

.PHONY: qa-changelog
qa-changelog: ## (4.2.3) Check that a non-empty CHANGELOG.md file exists
	@if [ -s CHANGELOG.md ]; then \
	  echo "✅ CHANGELOG.md file is present and non-empty"; \
	else \
	  echo "❌ CHANGELOG.md file is missing or empty"; exit 1; \
	fi

# ---------------------------------------------------------------------------
# Composite target
# ---------------------------------------------------------------------------

.PHONY: qa
qa: $(QA_TOOLS) qa-install ## Run all static QA checks (continues on failure, reports a summary)
	@failed=""; \
	for target in qa-lint qa-format qa-pynblint qa-figures qa-metadata qa-license qa-changelog; do \
	  echo ""; \
	  echo "==> $$target"; \
	  $(MAKE) --no-print-directory $$target || failed="$$failed $$target"; \
	done; \
	echo ""; \
	if [ -n "$$failed" ]; then \
	  echo "❌ Failed checks:"; \
	  for t in $$failed; do echo "   $$t"; done; \
	  exit 1; \
	else \
	  echo "✅ All checks passed"; \
	fi
