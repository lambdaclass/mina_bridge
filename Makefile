.PHONY: run

run:
	@echo "Generating public input for verifier circuit..."
	@cd public_input_gen && cargo r --release
	@echo "Done!"
	@echo "Proving verifier circuit..."
	@cd verifier_circuit && npm i && make
	@echo "Done!"
