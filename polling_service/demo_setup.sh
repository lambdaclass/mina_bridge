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
