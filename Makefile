SKILLS_DIR := $(HOME)/.claude/skills
SCRIPTS_DIR := $(HOME)/_scripts
REPO_DIR := $(CURDIR)

.PHONY: all install install-skills install-scripts uninstall uninstall-skills uninstall-scripts help

all: install

## install: Install skills, script, and prompts
install: install-skills install-scripts

## install-skills: Copy prd and ralph skills to ~/.claude/skills/
install-skills:
	@echo "Installing skills to $(SKILLS_DIR)..."
	@mkdir -p $(SKILLS_DIR)
	@cp -r skills/prd $(SKILLS_DIR)/
	@cp -r skills/ralph $(SKILLS_DIR)/
	@echo "Skills installed."

## install-scripts: Copy ralph.sh, AGENTS.md, CLAUDE.md to ~/_scripts/
install-scripts:
	@echo "Installing scripts to $(SCRIPTS_DIR)..."
	@mkdir -p -m 700 $(SCRIPTS_DIR)
	@cp $(REPO_DIR)/CLAUDE.md $(SCRIPTS_DIR)/CLAUDE.md
	@cp $(REPO_DIR)/AGENTS.md $(SCRIPTS_DIR)/AGENTS.md
	@cp $(REPO_DIR)/ralph.sh $(SCRIPTS_DIR)/ralph.sh
	@chmod +x $(SCRIPTS_DIR)/ralph.sh
	@echo "Scripts installed. Make sure $(SCRIPTS_DIR) is in your PATH."

## uninstall: Remove installed skills, script, and prompts
uninstall: uninstall-skills uninstall-scripts

## uninstall-skills: Remove prd and ralph skills from ~/.claude/skills/
uninstall-skills:
	@echo "Removing skills from $(SKILLS_DIR)..."
	@rm -rf $(SKILLS_DIR)/prd $(SKILLS_DIR)/ralph
	@echo "Skills removed."

## uninstall-scripts: Remove scripts from ~/_scripts/
uninstall-scripts:
	@echo "Removing scripts from $(SCRIPTS_DIR)..."
	@rm -f $(SCRIPTS_DIR)/CLAUDE.md $(SCRIPTS_DIR)/AGENTS.md $(SCRIPTS_DIR)/ralph.sh
	@echo "Scripts removed."

## help: Show available targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /' | column -t -s ':'
