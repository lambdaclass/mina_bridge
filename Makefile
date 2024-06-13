.PHONY: run check_account sepolia.wrap_and_deploy sepolia.verify

run:
	@echo "Setting up o1js..."
	@git submodule update --init --recursive
	@echo "Fetching state proof from Mina node..."
	@cd polling_service && sh run.sh
	@echo "Done!"
	@echo "Fetching Merkle root..."
	@cd state_utility && sh run.sh
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

check_account:
	@echo "Fetching Merkle path and leaf hash..."
	@cd state_utility/merkle_path && cargo r --release -- $(MINA_RPC_URL) ../../public_key.txt
	@echo "Done!"
	@echo "Verifying Merkle proof inclusion..."
	@cd eth_verifier && make setup && make merkle_locally
	@echo "Done!"

sepolia.wrap_and_deploy:
	@echo "Setting up o1js..."
	@git submodule update --init --recursive
	@echo "Fetching state proof from Mina node..."
	@cd polling_service && sh run.sh
	@echo "Done!"
	@echo "Creating circuit gates..."
	@cd verifier_circuit && npm i && make
	@echo "Done!"
	@echo "Creating KZG proof..."
	@cd kzg_prover && cargo r --release
	@echo "Done!"
	@echo "Fetching Merkle root..."
	@cd state_utility && sh run.sh
	@echo "Done!"
	@echo "Deploying verifier in Sepolia..."
	@cd eth_verifier && make sepolia.deploy_deser
	@echo "Done!"
	@echo "Once the verifier deployment is confirmed, set CONTRACT_ADDRESS env var and run:"
	@echo "  make sepolia.verify"

sepolia.verify:
	@echo "Uploading proof and Merkle root to Sepolia..."
	@cd eth_verifier && make sepolia.upload_proof_and_merkle_root
	@echo "Done!"
	@echo "Once the upload is confirmed in Sepolia, press any key to continue."; read REPLY
	@echo "Verifying uploaded proof in Sepolia..."
	@cd eth_verifier && make sepolia.verify
	@echo "Done!"
	@echo "Once the proof verification is confirmed in Sepolia, press any key to continue."; read REPLY
	@echo "Verifying Merkle proof inclusion in Sepolia..."
	@cd eth_verifier && make sepolia.merkle_verify
	@echo "Done!"
