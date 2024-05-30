.PHONY: build

build:
	@deno task preinstall
	@deno task build
	@deno run --max-old-space-size=32768 --unstable-sloppy-imports src/main.ts
