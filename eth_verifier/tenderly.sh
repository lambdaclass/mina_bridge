DEVNET_ID=2133ea48-9629-4625-9ea4-4540eb2e88ed
RPC_URL=https://rpc.vnet.tenderly.co/devnet/sepolia-devnet/$DEVNET_ID
TENDERLY_VERIFIER_URL=https://api.tenderly.co/api/v1/account/lambdaclassinfra/project/kimchi-evm-verifier/etherscan/verify/devnet/$DEVNET_ID
TENDERLY_ACCESS_KEY=0000000000000000000000
ETHERSCAN_API_KEY=$TENDERLY_ACCESS_KEY

curl $RPC_URL \
-X POST \
-H "Content-Type: application/json" \
-d '{
    "jsonrpc": "2.0",
    "method": "tenderly_setBalance",
    "params": [["0xcB4FCf27F0aF7156a1825D3f7FCd42c731b0B0d6"], "0xDE0B6B3A7640000"],
    "id": "1234"
}'

PRIVATE_KEY=0x3459054d09ae8631455b798b2b5d106e17bb4e68a39d2d2a935f5f1b7253988c \
forge script script/Verify.s.sol:Verify \
-vvv \
--rpc-url=$RPC_URL \
--etherscan-api-key '$ETHERSCAN_API_KEY' \
--non-interactive \
--via-ir --optimize --broadcast \
--sender 0xcB4FCf27F0aF7156a1825D3f7FCd42c731b0B0d6 \
--verify \
--verifier-url $TENDERLY_VERIFIER_URL
