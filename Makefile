.PHONY: run

run:
	@echo "Setting up o1js..."
	@git submodule update --init --recursive
	@echo "Fetching state proof from Mina node..."
	@cd polling_service && sh run.sh
	@echo "Done!"
	@echo "Generating public input for verifier circuit..."
	@cd public_input_gen && cargo r --release
	@echo "Done!"
	@echo "Creating circuit gates..."
	@cd verifier_circuit && npm i && make
	@echo "Done!"
	@echo "Creating KZG proof..."
	@cd kzg_prover && cargo r --release
	@echo "Done!"

