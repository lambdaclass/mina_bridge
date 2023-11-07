#!/bin/bash

export CONTRACT_ADDR=$1
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 

STATE=$(cat state.mpk)
PROOF=$(cat proof.mpk)

ENCODED_CALLDATA=$(cast calldata 'verify_state(bytes, bytes)' $STATE $PROOF)

cast send $CONTRACT_ADDR $ENCODED_CALLDATA --private-key $PRIVATE_KEY 1> /dev/null
echo "Verification transaction sent. Checking if it succeeded..."

if [ $(cast call $CONTRACT_ADDR "is_state_available()(bool)") == "true" ]; then
    echo "Successfully verified state. You can now run any of:"
    echo "cast call <CONTRACT_ADDR> 'retrieve_state_creator()(string)'"
    echo "cast call <CONTRACT_ADDR> 'retrieve_state_hash()(uint256)'"
    echo "cast call <CONTRACT_ADDR> 'retrieve_state_height()(uint256)'"
else
    echo "Verification failed."
fi
