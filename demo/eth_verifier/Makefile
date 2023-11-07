.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test -vv --via-ir

proof:
	cargo run --manifest-path ../circuit_gen/Cargo.toml --release

run_node:
	anvil --host 0.0.0.0

deploy_verifier:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/Deploy.s.sol:Deploy --via-ir --broadcast --rpc-url http://localhost:8545

query:
	cargo build --manifest-path ../state_serializer/Cargo.toml --release
	./query.sh | xargs -0 ../state_serializer/target/release/state_serializer > state.mpk

run_verifier_script:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/Deploy.s.sol:DeployIntegrated --via-ir --broadcast --rpc-url http://localhost:8545
