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
	@echo "Deploying and verifying in Anvil..."
	@cd eth_verifier && make setup && sh run.sh
	@echo "Done!"
	@echo "Save the last contract address, this is your verifier!"
	@echo "You can use cast to interact with it. Try calling:"
	@echo "    cast call <CONTRACT_ADDR> 'is_state_available()(bool)'"
	@echo "to check if verification succeded. If so, then you can retrieve state data:"
	@echo "    cast call <CONTRACT_ADDR> 'retrieve_state_creator()(string)'"
	@echo "    cast call <CONTRACT_ADDR> 'retrieve_state_hash()(uint256)'"
	@echo "    cast call <CONTRACT_ADDR> 'retrieve_state_height()(uint256)'"
