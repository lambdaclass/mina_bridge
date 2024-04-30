.PHONY: run demo.setup demo.valid demo.not_valid

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

demo.setup:
	@echo "Setting up o1js..."
	@git submodule update --init --recursive && cd verifier_circuit/o1js && npm i
	@echo "Done!"
	@echo "Setting up polling service..."
	@cd polling_service && sh demo_setup.sh
	@echo "Done!"
	@echo "Setting up verifier circuit..."
	@cd verifier_circuit && npm i
	@echo "Done!"
	@echo "Deploying verifier to Sepolia..."
	@cd eth_verifier && make sepolia.deploy

demo.valid:
	@echo "Fetching state proof from Mina node..."
	@cd polling_service && sh demo_run.sh
	@echo "Done!"
	@echo "Generating public input for verifier circuit..."
	@cd public_input_gen && cargo r --release
	@echo "Done!"
	@echo "Creating circuit gates..."
	@cd verifier_circuit && make
	@echo "Done!"
	@echo "Creating KZG proof..."
	@cd kzg_prover && cargo r --release
	@echo "Done!"
	@echo "Uploading proof and verifying it..."
	@cd eth_verifier && make sepolia.upload_proof && make sepolia.verify
	@echo "Done!"

demo.not_valid:
	@echo "Fetching state proof from Mina node..."
	@cd polling_service && sh demo_run.sh
	@echo "Done!"
	@echo "Generating public input for verifier circuit..."
	@cd public_input_gen && cargo r --release
	@echo "Done!"
	@echo "Creating circuit gates..."
	@cd verifier_circuit && make
	@echo "Done!"
	@echo "Creating KZG proof..."
	@cd bad_kzg_prover && cargo r --release
	@echo "Done!"
	@echo "Uploading proof and verifying it..."
	@cd eth_verifier && make sepolia.upload_proof && make sepolia.verify
	@echo "Done!"
