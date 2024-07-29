.PHONY: run gen_contract_abi deploy_contract

run:
	@cargo run --manifest-path core/Cargo.toml --release

gen_contract_abi:
	forge build --root contract/
	cp contract/out/MinaBridge.sol/MinaBridge.json core/abi/MinaBridge.json

deploy_contract_anvil:
	forge script \
	--non-interactive \
	--root contract/ \
	--broadcast \
	--rpc-url http://localhost:8545 \
	--private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6 \
	contract/script/MinaBridge.s.sol:MinaBridgeDeployer
# deploy_contract_anvil uses Anvil wallet 9, same as Aligned for deploying its contracts.
