.PHONY: ci spec-check m5-evidence

spec-check:
	bash scripts/spec-check.sh

ci: spec-check

m5-evidence:
	@bash scripts/m5-test-evidence.sh
