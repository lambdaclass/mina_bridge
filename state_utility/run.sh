#!/bin/sh

git clone https://github.com/lambdaclass/mina.git -b merkle_root_parser --recursive mina_3_0_0_devnet

cargo r \
    --manifest-path parser/Cargo.toml\
    --release \
    -- $MINA_RPC_URL ./mina_3_0_0_devnet/src/lib/merkle_root_parser/merkle_root.txt

cd mina_3_0_0_devnet/src/lib/merkle_root_parser
opam exec -- dune exec ./bin/main.exe > ../../../../merkle_root/merkle_root.txt
cd ../../../..

cargo r \
    --manifest-path ./merkle_root/Cargo.toml\
    --release \
    -- ./merkle_root/merkle_root.txt ../eth_verifier/merkle_root.bin ../verifier_circuit/src/merkle_root.json
