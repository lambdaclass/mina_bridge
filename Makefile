.PHONY: build_test_prover

build_test_prover:
	@cd test_prover && npm install && npm run build && node build/src/main.js
