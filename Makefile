.PHONY: ci spec-check

spec-check:
	bash scripts/spec-check.sh

ci: spec-check
