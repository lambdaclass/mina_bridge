.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test -vv --via-ir --optimize --gas-report

run_node:
	anvil

run_locally:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Verify.s.sol:Verify --via-ir --optimize --broadcast --rpc-url http://localhost:8545

deploy_sepolia:
	forge script --rpc-url $RPC_URL --broadcast \
    --private-key $PRIVATE_KEY \
    --chain-id 11155111 \
    --verify --delay 10 \
    script/Deploy.s.sol:Deploy
