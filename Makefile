.PHONY: run

run:
	@echo "Fetching Mina protocol state and its proof..."
	@cargo run --manifest-path polling_service/parser/Cargo.toml --release -- ${MINA_RPC_URL}
