.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test -vv

proof:
	cd circuit_gen && cargo run

run_node:
	anvil --host 0.0.0.0

deploy_verifier:
	forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url http://localhost:8545
