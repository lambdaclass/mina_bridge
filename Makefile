.PHONY: run

run:
	@echo "Fetching Mina protocol state and its proof..."
	@cargo run --manifest-path polling_service/parser/Cargo.toml --release -- ${MINA_RPC_URL} .
	@echo "Done!"
	@echo "Sending Mina protocol state and its proof to Aligned..."
	@cargo run --manifest-path ${ALIGNED_PATH}/batcher/aligned/Cargo.toml --release -- submit \
		--proving_system Mina \
		--proof protocol_state.proof \
		--public_input protocol_state.pub \
		--proof_generator_addr 0x66f9664f97F2b50F62D13eA064982f936dE76657
	@echo "Done!"

verify_account:
	@echo "Generating proof of account inclusion..."
	@cargo run --manifest-path account_inclusion/script/Cargo.toml --release
	@echo "Done!"
	@echo "Sending Account inclusion proof to Aligned..."
	@cargo run --manifest-path ${ALIGNED_PATH}/batcher/aligned/Cargo.toml --release -- submit \
		--proving_system SP1 \
		--proof account_inclusion.proof \
		--vm_program account_inclusion/program/elf/riscv32im-succinct-zkvm-elf \
		--proof_generator_addr 0x66f9664f97F2b50F62D13eA064982f936dE76657
	@echo "Done!"
