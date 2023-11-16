(anvil &)

echo "Waiting for local blockchain..."
sleep 3

PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script \
    --via-ir \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    script/Deploy.s.sol:DeployAndVerify

echo "After interacting with your contract, don't forget to kill the Anvil process:"
echo "    pkill anvil"
