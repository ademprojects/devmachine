.PHONY: help lint yamllint ansible-lint syntax check

PLAYBOOK ?= playbooks/devmachine.yml
INVENTORY ?= inventory.ini

help:
	@echo "Targets:"
	@echo "  make lint          — yamllint + ansible-lint"
	@echo "  make yamllint      — yamllint only"
	@echo "  make ansible-lint  — ansible-lint only"
	@echo "  make syntax        — ansible-playbook --syntax-check on $(PLAYBOOK)"
	@echo "  make check         — lint + syntax (run before commit)"

yamllint:
	yamllint .

ansible-lint:
	ansible-lint

lint: yamllint ansible-lint

syntax:
	ansible-playbook --syntax-check -i $(INVENTORY) $(PLAYBOOK)

check: lint syntax
