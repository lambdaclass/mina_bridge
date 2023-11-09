#!/bin/sh

fetchproof() {
	curl -d '{"query": "{
    bestChain(maxLength: 1) {
                  protocolStateProof {
        base64
      }
    }
  }"}' -H 'Content-Type: application/json' http://5.9.57.89:3085/graphql
}

PROOF=$(fetchproof)

if [ $? -eq 0 ]; then
	echo $PROOF | grep 'errors'

	if [ $? -eq 0 ]; then
		echo >&2 "Warning: Mina node is not synced. Using old proof file."
	else
		echo $PROOF | sed -e 's@{\"data\":{\"bestChain":\[{\"protocolStateProof\":{\"base64\":\"@@' |
			sed -e 's@\(.*\)\"}}]}}@\1====@' | fold -w 4 | sed '$ d' | tr -d '\n' >proof.txt
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
opam init -n --disable-sandboxing
opam switch import opam.export
eval $(opam env)
sh scripts/pin-external-packages.sh
make build
cd src/lib/proof_parser
dune build
dune exec ./proof_parser.exe >../../../../../public_input_gen/src/proof.json
