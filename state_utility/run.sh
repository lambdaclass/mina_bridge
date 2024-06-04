git clone https://github.com/lambdaclass/mina.git -b 3.0.0devnet --recursive mina_3_0_0_devnet
cd mina_3_0_0_devnet/src/lib/merkle_root_parser
opam exec -- dune exec bin/main.exe
