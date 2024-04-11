DEVNET_ID=4b64f6ab-2cd8-4f75-a89e-10c739447b2d
RPC_URL=https://rpc.vnet.tenderly.co/devnet/sepolia-devnet/$DEVNET_ID
TENDERLY_VERIFIER_URL=https://api.tenderly.co/api/v1/account/lambdaclassinfra/project/kimchi-evm-verifier/etherscan/verify/devnet/$DEVNET_ID
TENDERLY_ACCESS_KEY=R5rG-xNm1X40p9PmEmCE1b7wp25Yi8hK
ETHERSCAN_API_KEY=R5rG-xNm1X40p9PmEmCE1b7wp25Yi8hK

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
--etherscan-api-key 'R5rG-xNm1X40p9PmEmCE1b7wp25Yi8hK' \
--non-interactive \
--via-ir --optimize --broadcast \
--sender 0xcB4FCf27F0aF7156a1825D3f7FCd42c731b0B0d6 \
--verify \
--verifier-url $TENDERLY_VERIFIER_URL
