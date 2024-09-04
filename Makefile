.PHONY: submit-state submit-account gen_contract_abi deploy_contract

submit_state:
	@cargo run --manifest-path core/Cargo.toml --release -- submit-state

submit_account:
	@cargo run --manifest-path core/Cargo.toml --release -- submit-account ${PUBLIC_KEY} ${STATE_HASH}

gen_contract_abi:
	forge build --root contract/
	cp contract/out/MinaBridge.sol/MinaBridge.json core/abi/MinaBridge.json

deploy_contract: gen_contract_abi
	@cargo run --manifest-path contract_deployer/Cargo.toml --release
