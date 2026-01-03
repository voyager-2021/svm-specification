#
# UV-based virtual environment management
#

WORKDIR ?= .
VENVDIR ?= $(WORKDIR)/.venv
VENV     = $(VENVDIR)/bin
EXE      =
MARKER   = .initialized-with-Makefile

REQUIREMENTS_TXT ?= $(wildcard requirements.txt)
SETUP_PY ?= $(wildcard setup.py)

# Windows detection
ifeq (win32,$(shell python -c "import sys; print(sys.platform)" 2>/dev/null))
VENV := $(VENVDIR)/Scripts
EXE  := .exe
endif

RM ?= rm -f
RMDIR ?= rm -rf

#
# Virtual environment
#

.PHONY: venv
venv: $(VENV)/$(MARKER)

$(VENV):
	uv venv $(VENVDIR)

$(VENV)/$(MARKER): | $(VENV)
ifneq ($(strip $(REQUIREMENTS_TXT)),)
	uv pip install $(foreach r,$(REQUIREMENTS_TXT),-r $(r))
endif
ifneq ($(strip $(SETUP_PY)),)
	uv pip install -e .
endif
	@touch $@

.PHONY: clean-venv
clean-venv:
	-$(RMDIR) "$(VENVDIR)"

.PHONY: show-venv
show-venv: venv
	@"$(VENV)/python" -c "import sys; print('Python ' + sys.version.replace('\n',''))"
	@uv --version
	@echo venv: $(VENVDIR)

#
# Interactive shells
#

.PHONY: python
python: venv
	exec "$(VENV)/python"

.PHONY: shell
shell: venv
	. "$(VENV)/activate" && exec $(notdir $(SHELL))

.PHONY: bash zsh
bash zsh: venv
	. "$(VENV)/activate" && exec $@

#
# Command-line tools (lazy install via uv)
#

ifneq ($(EXE),)
$(VENV)/%: $(VENV)/%$(EXE) ;
.PHONY:    $(VENV)/%
.PRECIOUS: $(VENV)/%$(EXE)
endif

$(VENV)/%$(EXE): venv
	uv pip install --upgrade $*
	@touch $@
