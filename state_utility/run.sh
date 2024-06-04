cd parser
cargo r --release
cd ..
git clone https://github.com/lambdaclass/mina.git -b merkle_root_parser --recursive mina_3_0_0_devnet
cd mina_3_0_0_devnet/src/lib/merkle_root_parser
opam exec -- dune exec bin/main.exe > ../../../../../merkle-path/merkle_root.txt
