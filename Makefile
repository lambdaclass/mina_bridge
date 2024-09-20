.PHONY: submit-state submit-account gen_contract_abi deploy_contract

submit_state:
	@cargo run --manifest-path core/Cargo.toml --release -- submit-state

submit_account:
	@cargo run --manifest-path core/Cargo.toml --release -- submit-account ${PUBLIC_KEY} ${STATE_HASH}

gen_contract_abis:
	forge build --root contract/
	forge build --root example/eth_contract
	cp contract/out/MinaBridge.sol/MinaBridge.json core/abi/MinaBridge.json
	cp contract/out/MinaAccountValidation.sol/MinaAccountValidation.json core/abi/MinaAccountValidation.json
	cp example/eth_contract/out/SudokuValidity.sol/SudokuValidity.json example/app/abi/SudokuValidity.json

deploy_contract: gen_contract_abis
	@cargo run --manifest-path contract_deployer/Cargo.toml --release

deploy_example_contract: gen_contract_abis
	@cargo run --manifest-path example/app/Cargo.toml --release -- deploy-contract

execute_example:
	cd example/mina_contract & npm run build & node build/src/run.js
	cargo run --manifest-path example/app/Cargo.toml --release -- validate-solution
