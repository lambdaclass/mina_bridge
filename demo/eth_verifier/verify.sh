#!/bin/bash

export CONTRACT_ADDR=$1

if [ $CONTRACT_ADDR == "0x0" ]; then
    echo "Please edit this script and set your contract address."
    exit 1
fi

STATE=$(cat state.mpk)
PROOF=$(cat proof.mpk)

success=$(cast call $CONTRACT_ADDR 'verify_state(bytes calldata, bytes calldata)' $STATE $PROOF)
asd=$(cast call $CONTRACT_ADDR 'store_state(bytes calldata)' $STATE)
if [ $success == "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "Successfully verified state. You can now run any of retrieve_state_X()."
fi
