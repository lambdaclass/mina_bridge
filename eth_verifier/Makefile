.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test -vv --via-ir --optimize --gas-report

run_node:
	anvil --gas-limit 18446744073709551615 --code-size-limit 32768

deploy_and_verify:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Deploy.s.sol:DeployAndVerify --via-ir --optimize --broadcast --rpc-url http://localhost:8545

verify:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Serialize.s.sol:Serialize --via-ir --optimize --broadcast --rpc-url http://localhost:8545 & \
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Verify.s.sol:Verify --via-ir --optimize --broadcast --rpc-url http://localhost:8545

serialize:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Serialize.s.sol:Serialize --via-ir --optimize --broadcast --rpc-url http://localhost:8545

tenderly:
	PRIVATE_KEY=0x3459054d09ae8631455b798b2b5d106e17bb4e68a39d2d2a935f5f1b7253988c \
	forge script --non-interactive script/Verify.s.sol:Verify --via-ir --optimize --broadcast --rpc-url=$(TENDERLY_DEVNET_RPC_URL) --sender 0xcB4FCf27F0aF7156a1825D3f7FCd42c731b0B0d6
