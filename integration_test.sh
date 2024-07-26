mkdir integration_test
cd integration_test
git clone git@github.com:lambdaclass/aligned_layer.git --recursive -b mina
cd aligned_layer
make submodules deps go_deps

if [ $TARGET == linux ]
then
    make build_mina_linux
else
    make build_mina_macos
fi

echo `AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_REGION=us-west-2
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_BUCKET_NAME=mina_bridge
RUST_LOG=error
` > batcher/aligned-batcher/.env

echo "Starting local devnet..."
make anvil_start_with_block_time &
sleep 5
echo "Starting Aggregator..."
make aggregator_start &
sleep 5
echo "Starting Operator..."
make operator_register_and_start &
sleep 60
echo "Starting Batcher..."
make batcher_start &
sleep 15

cd ../..

# First proof
make &
sleep 30

# Complete batch
make
