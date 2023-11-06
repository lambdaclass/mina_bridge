# Solidity Verifier

This is the demo's Mina state verifier in solidity, implemented using Foundry. The contract exposes an API for retrieving zk-verified data from the last Mina state.

Install dependencies by running:
```bash
make setup
```

## Local usage and deployment
The contract can be deployed in an Anvil local node.

Start the local chain with:
```bash
make run_node
```
then deploy the contract:
```bash
make deploy_verifier
```
after deployment Anvil will return a list of deployed contracts, as it will also deploy needed libraries for the verifier:
```bash
...

##### anvil-hardhat
✅  [Success]Hash: 0x312036beb087e610e6ba100a1ef0653c31c28db4a924aee13e6550a4181a31ed
Contract Address: 0x67d269191c92Caf3cD7723F116c85e6E9bf55933
Block: 17
Paid: 0.005753394722296 ETH (1825720 gas * 3.1513018 gwei)


Transactions saved to: eth_verifier/broadcast/Deploy.s.sol/31337/run-latest.json

Sensitive values saved to: eth_verifier/cache/Deploy.s.sol/31337/run-latest.json
```
the last contract deployed is the verifier, **save its address as we'll use it in a later step**.

You can query data from the last Mina state and serialize it into MessagePack, needed for calling the contract:
```bash
make query
```
building a KZG proof of the state is still WIP, so you can find a `proof.mpk` containing only the data needed for running the current verifier, which is also WIP.

You can then run the verifier by calling the `verify_state()` function using `cast`. For this we provided a utility script `verify.sh` **which you need to edit to input the verifier contract address**, run it with:
```bash
make verify
```
then you can get State data from the contract storage:
```bash
cast call $CONTRACT_ADDR 'retrieve_state_creator()'
cast call $CONTRACT_ADDR 'retrieve_state_hash()'
cast call $CONTRACT_ADDR 'retrieve_state_height()'
```
or by running:
```bash
make retrieve
```

## Testing

Just run:
```bash
make test
```
