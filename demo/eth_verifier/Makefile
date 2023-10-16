.PHONY: all proof

all: proof
	solc --bin verifier.sol

proof:
	cd circuit_gen && cargo run
