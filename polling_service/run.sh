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
        base64
      }
    }
  }"}' -H 'Content-Type: application/json' http://5.9.57.89:3085/graphql
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

git clone https://github.com/lambdaclass/mina.git mina_1_4_0
cd mina_1_4_0
git remote add o1labs git@github.com:MinaProtocol/mina.git
git checkout proof_to_json
git submodule update --init --recursive
# only to make it more OCaml friendly and not mess up with the user local
# environment
if [ ! -d "$(pwd)/_opam" ]; then
  opam switch create ./ 4.14.0 -y
fi
eval $(opam env)
opam switch import opam.export -y
sh scripts/pin-external-packages.sh
make build
cd src/lib/proof_parser
dune build
dune exec ./proof_parser.exe > ../../../../../public_input_gen/src/proof.json
