(anvil --gas-limit 18446744073709551615 --code-size-limit 32768 &)

echo "Waiting for local blockchain..."
sleep 3

make run_locally

echo "After interacting with your contract, don't forget to kill the Anvil process:"
echo "    pkill anvil"
