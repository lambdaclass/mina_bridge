curl -d '{"query": "{
  bestChain(maxLength: 1) {
                protocolStateProof {
      base64
    }
  }
}"}' -H 'Content-Type: application/json' http://5.9.57.89:3085/graphql | sed -e 's@{\"data\":{\"bestChain":\[{\"protocolStateProof\":{\"base64\":\"@@' \
	| sed -e 's@\(.*\)\"}}]}}@\1====@' | fold -w 4 | sed '$ d' | tr -d '\n' > proof.txt

git clone git@github.com:lambdaclass/mina.git mina_1_4_0
cd mina_1_4_0
git remote add o1labs git@github.com:MinaProtocol/mina.git
git checkout proof_to_json
git submodule update --init --recursive
opam init -n
opam switch import opam.export
sh scripts/pin-external-packages.sh
make build
cd src/lib/proof_parser
dune build
dune exec ./proof_parser.exe > ../../../../../verifier_circuit/src/proof.json
