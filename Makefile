.PHONY: run setup_test

run:
	@cargo run --manifest-path core/Cargo.toml --release

setup_test:
	@bash integration_test.sh