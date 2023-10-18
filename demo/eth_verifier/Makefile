.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

test:
	forge test

proof:
	cd circuit_gen && cargo run
