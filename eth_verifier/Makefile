.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test -vv --via-ir

run_node:
	anvil --gas-limit 18446744073709551615 --code-size-limit 32768

deploy_and_verify:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Deploy.s.sol:DeployAndVerify --via-ir --broadcast --rpc-url http://localhost:8545

verify:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Verify.s.sol:Verify --via-ir --broadcast --rpc-url http://localhost:8545

serialize:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Serialize.s.sol:Serialize --via-ir --broadcast --rpc-url http://localhost:8545
