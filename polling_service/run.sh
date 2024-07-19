#!/bin/sh

fetch() {
  curl -d '{"query": "{
    protocolState(encoding: BASE64)
    bestChain(maxLength: 1) {
      protocolStateProof {
        base64
      }
      stateHashField
    }
  }"}' -H 'Content-Type: application/json' $MINA_RPC_URL
}

DATA=$(fetch)

echo $DATA | jq -r '.data.bestChain.[0].stateHashField' >protocol_state_hash.pub
echo $DATA | jq -r '.data.protocolState' >protocol_state.pub
echo $DATA | jq -r '.data.bestChain.[0].protocolStateProof.base64' >protocol_state_proof.proof
