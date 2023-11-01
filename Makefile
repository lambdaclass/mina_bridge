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
	@echo "Proving verifier circuit..."
	@cd verifier_circuit && npm i && make
	@echo "Done!"
	@echo "Verifying proof..."
	@cd demo/eth_verifier
	@anvil &
	@cd demo/eth_verifier && \
		forge create \
			--rpc-url 127.0.0.1:8545 \
			--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
			src/Fields.sol:Scalar && \
		forge create \
			--rpc-url 127.0.0.1:8545 \
			--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
			src/Utils.sol:Utils && \
		forge create \
			--rpc-url 127.0.0.1:8545 \
			--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
			src/Verifier.sol:KimchiVerifier && \
	@pkill anvil
