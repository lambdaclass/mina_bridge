.PHONY: run

run:
	@echo "Fetching Mina protocol state and its proof..."
	@cargo run --manifest-path polling_service/parser/Cargo.toml --release -- ${MINA_RPC_URL}
	@echo "Done!"
	@echo "Sending Mina protocol state and its proof to Aligned..."
	@cargo run --manifest-path ${ALIGNED_PATH}/batcher/aligned/Cargo.toml --release -- submit \
		--proving_system Mina \
		--proof protocol_state_proof.proof \
		--public_input protocol_state_hash.pub \
		--proof_generator_addr 0x66f9664f97F2b50F62D13eA064982f936dE76657
	@echo "Done!"

