.PHONY: run setup_test

run:
	@cargo run --manifest-path core/Cargo.toml --release

setup_test:
	@sh integration_test.sh