#!/bin/sh

fetch() {
  curl -d '{"query": "{
    bestChain(maxLength: 1) {
      protocolState {
        previousStateHash
      }
      protocolStateProof {
        base64
      }
    }
  }"}' -H 'Content-Type: application/json' $MINA_RPC_URL
}

DATA=$(fetch)

if [ $? -eq 0 ]; then
	echo $PROOF | grep 'errors'

	if [ $? -eq 0 ]; then
		echo >&2 "Error: Mina node is not synced."
    exit 1
	else
    cargo run --manifest-path parser/Cargo.toml --release -- $DATA && \
    echo "State hash and proof fetched from Mina node successfully!"
	fi
else
	echo >&2 "Error: Couldn't connect to Mina node."
  exit 1
fi

