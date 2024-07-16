.PHONY: run

run:
	@echo "Fetching Mina protocol state and its proof..."
	@cd polling_service && sh run.sh
