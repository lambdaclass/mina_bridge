#!/bin/sh

fetch() {
  curl -d '{"query": "{
    bestChain(maxLength: 1) {
      creator
      stateHashField
      protocolState {
        consensusState {
          blockHeight
        }
      }

      protocolStateProof {
        json
      }
    }
  }"}' -H 'Content-Type: application/json' $MINA_RPC_URL
}

DATA=$(fetch)

if [ $? -eq 0 ]; then
	echo $PROOF | grep 'errors'

	if [ $? -eq 0 ]; then
		echo >&2 "Warning: Mina node is not synced. Using old proof file."
	else
    cargo run --manifest-path parser/Cargo.toml --release -- $DATA
		echo "State proof fetched from Mina node successfully!"
	fi
else
	echo >&2 "Warning: Couldn't connect to Mina node. Using old proof file."
fi

