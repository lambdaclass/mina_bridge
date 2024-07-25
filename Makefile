.PHONY: run

run:
	@cargo run --manifest-path core/Cargo.toml --release

gen_contract_abi:
	forge build --root contract/
	cp contract/out/MinaBridge.sol/MinaBridge.json core/abi/MinaBridge.json
