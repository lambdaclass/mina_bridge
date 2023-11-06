#!/bin/bash

export CONTRACT_ADDR=0x67d269191c92Caf3cD7723F116c85e6E9bf55933 # replace this after deploying

if [ $CONTRACT_ADDR == "0x0" ]; then
    echo "Please edit this script and set you contract address."
    exit 1
fi

STATE=$(cat state.mpk)
PROOF=$(cat proof.mpk)

success=$(cast call $CONTRACT_ADDR 'verify_state(bytes calldata, bytes calldata)' $STATE $PROOF)
if [ $success == "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "Successfully verified state. You can now run any of retrieve_state_X()."
fi
