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
	forge script --non-interactive script/Verify.s.sol:VerifyAndCheckAccount --broadcast --rpc-url http://localhost:8545

merkle_locally:
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script --non-interactive script/Verify.s.sol:MerkleVerify --broadcast --rpc-url http://localhost:8545

sepolia.deploy:
	forge script --rpc-url ${RPC_URL} --broadcast \
    --private-key ${PRIVATE_KEY} \
    --chain-id 11155111 \
    --verify --delay 5 \
	--legacy \
    script/Deploy.s.sol:Deploy

sepolia.upload_proof:
	forge script --rpc-url ${RPC_URL} --broadcast \
    --private-key ${PRIVATE_KEY} \
    --chain-id 11155111 \
	--legacy \
    script/UploadProof.s.sol:UploadProof

sepolia.deploy_deser:
	forge script --rpc-url ${RPC_URL} --broadcast \
    --private-key ${PRIVATE_KEY} \
    --chain-id 11155111 \
    --verify --delay 5 \
	--legacy \
    script/Deploy.s.sol:DeployAndDeser

sepolia.verify:
	forge script --rpc-url ${RPC_URL} --broadcast \
    --private-key ${PRIVATE_KEY} \
    --chain-id 11155111 \
    --verify --delay 5 \
	--legacy \
    script/Verify.s.sol:PartialAndFinalVerify
