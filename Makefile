.PHONY: run gen_contract_abi deploy_contract

run:
	@cargo run --manifest-path core/Cargo.toml --release

gen_contract_abi:
	forge build --root contract/
	cp contract/out/MinaBridge.sol/MinaBridge.json core/abi/MinaBridge.json

deploy_contract_anvil:
	@cargo run --manifest-path contract_deployer/Cargo.toml --release

verify_account_inclusion:
	@cargo run --manifest-path account_inclusion/Cargo.toml --release -- ${PUBLIC_KEY}
