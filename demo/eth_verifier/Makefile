.PHONY: test setup

setup:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

ci:
	curl -L https://foundry.paradigm.xyz | bash
	source /home/runner/.bashrc && foundryup

test:
	forge test -vv

proof:
	cd circuit_gen && cargo run
