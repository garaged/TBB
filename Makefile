.PHONY: ci spec-check test-evidence

spec-check:
	bash scripts/spec-check.sh

ci: spec-check

test-evidence:
	@bash scripts/test-evidence.sh
