#!/bin/sh

git clone https://github.com/lambdaclass/mina.git -b merkle_root_parser --recursive mina_3_0_0_devnet

cargo r \
    --manifest-path parser/Cargo.toml\
    --release \
    -- ./mina_3_0_0_devnet/src/lib/merkle_root_parser/merkle_root.txt

opam exec -- dune exec ./mina_3_0_0_devnet/src/lib/merkle_root_parser/bin/main.exe > ../../../../../state_utility/merkle_root/merkle_root.txt

cargo r \
    --manifest-path ./merkle_root/Cargo.toml\
    --release \
    -- ../eth_verifier/merkle_root.bin
