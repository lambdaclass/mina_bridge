.PHONY: run

run:
	@echo "Generating public input for verifier circuit..."
	@cd public_input_gen && cargo r --release
	@echo "Done!"
	@echo "Generating verifier circuit..."
	@cd evm_bridge && npm i && make
	@echo "Done!"
	@echo "Proving verifier circuit..."
	@cd kzg_prover && cargo r --release
	@echo "Done!"
