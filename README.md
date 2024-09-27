<div align="center">

# mina_bridge 🌉

## Zero-knowledge state bridge from Mina to Ethereum

</div>

## About

This project introduces the verification of [Mina Protocol](https://minaprotocol.com/) states and accounts in Ethereum, which will serve as a foundation for applications and infrastructure that take advantage of bridged blockchain and zkApp state.

The bridge leverages [Aligned Layer](https://github.com/yetanotherco/aligned_layer) to verify Mina Proofs of State and Mina Proofs of Account in Ethereum.

## Usage

### Setup

### Mina node

- If you want the Bridge to use Mina Devnet then use a node that runs a Devnet instance corresponding to the commit `599a76d` [of the Mina repo](https://github.com/MinaProtocol/mina/tree/599a76dd47be99183d2102d9eb93eda679dd46ec) or a newer one (e.g.: [this Docker image](https://console.cloud.google.com/gcr/images/o1labs-192920/GLOBAL/mina-daemon:3.0.1-compatible-599a76d-bullseye-devnet/details)). See [how to connect to Mina Devnet](https://docs.minaprotocol.com/node-operators/block-producer-node/connecting-to-devnet#docker) if you want to run an instance yourself.
- If you want the Bridge to use Mina Mainnet use a node that runs a Mainnet instance corresponding to the commit `65c84ad` [of the Mina repo](https://github.com/MinaProtocol/mina/tree/65c84adacd55272160d9f77c31063d94a942afb6) or a newer one (e.g.: [this Docker image](https://console.cloud.google.com/gcr/images/o1labs-192920/GLOBAL/mina-daemon:65c84ada-bullseye-mainnet/details?tab=info)). See [how to connect to Mina Mainnet](https://docs.minaprotocol.com/node-operators/block-producer-node/connecting-to-the-network#docker) if you want to run an instance yourself.

You can bridge Mina accounts to Ethereum Devnet or Ethereum Testnet. The following subsections describe how to config the Bridge for each network.

#### Ethereum Devnet

1. [Setup Aligned Devnet locally](https://github.com/yetanotherco/aligned_layer/blob/main/docs/guides/3_setup_aligned.md#booting-devnet-with-default-configs)
1. Setup the `.env` file of the Bridge. A template is available in `.env.template`.
    1. Set `ETH_CHAIN` to `devnet`.
    1. Set `MINA_RPC_URL` to the URL of the Mina node GraphQL API (See [Mina node section](#mina-node)).

#### Ethereum Testnet

Because the Bridge uses for now a forked version of Aligned, you may need to setup a local instance of Aligned to verify Mina proofs.

##### Aligned Testnet setup

You will need two Ethereum accounts: One to fund the Aligned operator (`operator_account_address`) and another to fund the Aligned batcher (`batcher_account_address`).

1. Clone the [forked Aligned repo](https://github.com/lambdaclass/aligned_layer). Checkout to the `aligned` branch.
1. Run:

  ```sh
  make deps go_deps
  ```

1. Copy the EigenLayer Holešky deployment config file into Aligned:

  ```sh
  cp contracts/lib/eigenlayer-middleware/lib/eigenlayer-contracts/script/configs/holesky/Holesky_current_deployment.config.json contracts/script/output/holesky
  ```

1. Set `contracts/script/deploy/config/holesky/aligned.holesky.config.json` to:

  ```json
  {
    "chainInfo": {
      "chainId": 17000
    },
    "permissions": {
      "owner": "<operator_account_address>",
      "aggregator": "<operator_account_address>",
      "upgrader": "<operator_account_address>",
      "churner": "<operator_account_address>",
      "ejector": "<operator_account_address>",
      "deployer": "<operator_account_address>",
      "initalPausedStatus": 0
    },
    "minimumStakes": [
      1
    ],
    "strategyWeights": [
      [
        {
          "0_strategy": "0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9",
          "1_multiplier": 1e+18
        }
      ]
    ],
    "operatorSetParams": [
      {
        "0_maxOperatorCount": 200,
        "1_kickBIPsOfOperatorStake": 11000,
        "2_kickBIPsOfTotalStake": 50
      }
    ],
    "uri": ""
  }
  ```

1. Setup the `contracts/scripts/.env` file. A template is available in `contracts/scripts/.env.example.holesky`. Set `PRIVATE_KEY` to the private key of the account you chose to fund the operator (the one with address `operator_account_address`).
1. Set `contracts/script/output/holesky/alignedlayer_deployment_output.json` to:

  ```json
  {
    "addresses": {
      "alignedLayerProxyAdmin": "0x715e3F1c9F58832a606cf85C328250af32d20E93",
      "alignedLayerServiceManager": "0x4d879A997f422FeB8AC2f3d9Dcc749e9d8d0E4a4",
      "alignedLayerServiceManagerImplementation": "0x63257B1e36B78cb8be08A5A42317B93D7127D56b",
      "blsApkRegistry": "0xf1e92D804230Cdb88D95A79e8D6E5B4e3182E632",
      "blsApkRegistryImplementation": "0x6d3Bf64adAd29949766417543eF2eb8670964426",
      "indexRegistry": "0xd2062Fb412923bE70F4d51E361Fe17408eE4b1b0",
      "indexRegistryImplementation": "0x5Ee29B5d21CDA0ac24645Cb25DcdB9759E89628B",
      "operatorStateRetriever": "0x38a45de56c29a3929Bb68aFD51d4B28F158d2900",
      "registryCoordinator": "0x5EA37f0FdF065c047cdC0a5Ee7b3b99aC16C2B4a",
      "registryCoordinatorImplementation": "0xE3Cef87B26f1A4CA37aF548e058f660F22Ef2E76",
      "serviceManagerRouter": "0x6aA8AbaC32500eab9b67D4259602535619A6B919",
      "stakeRegistry": "0x1763e9cEC4137a2031985A5D813dF5dC36ED71Ff",
      "stakeRegistryImplementation": "0xd4a7d36B2c049613BEb5Ade3d92Af82aFc4a12d6"
    },
    "chainInfo": {
      "chainId": 17000,
      "deploymentBlock": 2421617
    },
    "permissions": {
      "alignedLayerAggregator": "<operator_account_address>",
      "alignedLayerChurner": "<operator_account_address>",
      "alignedLayerEjector": "<operator_account_address>",
      "alignedLayerOwner": "<operator_account_address>",
      "alignedLayerUpgrader": "<operator_account_address>",
      "pauserRegistry": "0x85Ef7299F8311B25642679edBF02B62FA2212F06"
    }
  }
  ```

1. Create 3 EigenLayer keystores:
    1. Aggregator and operator ECDSA:

    ```sh
    eigenlayer operator keys import --key-type ecdsa mina_bridge <operator_account_private_key>
    ```

    1. Aggregator and operator BLS:

    ```sh
    eigenlayer operator keys import --key-type bls mina_bridge <operator_account_private_key>
    ```

    1. Batcher ECDSA:

    ```sh
    eigenlayer operator keys import --key-type ecdsa mina_bridge.batcher <batcher_account_private_key>
    ```

1. Create `config-files/holesky/config.yaml` and set it to:

  ```yaml
  # Common variables for all the services
  # 'production' only prints info and above. 'development' also prints debug
  environment: "production"
  aligned_layer_deployment_config_file_path: "./contracts/script/output/holesky/alignedlayer_deployment_output.json"
  eigen_layer_deployment_config_file_path: "./contracts/script/output/holesky/eigenlayer_deployment_output.json"
  eth_rpc_url: "https://holesky.internal.lambdaclass.com"
  eth_rpc_url_fallback: "https://holesky.internal.lambdaclass.com"
  eth_ws_url: "wss://ws.holesky.internal.lambdaclass.com"
  eth_ws_url_fallback: "wss://ws.holesky.internal.lambdaclass.com"
  eigen_metrics_ip_port_address: "localhost:9090"

  ## ECDSA Configurations
  ecdsa:
    private_key_store_path: "<home>/.eigenlayer/operator_keys/mina_bridge.ecdsa.key.json"
    private_key_store_password: "<password_used_to_create_keystore>"

  ## BLS Configurations
  bls:
    private_key_store_path: "<home>/.eigenlayer/operator_keys/mina_bridge.bls.key.json"
    private_key_store_password: "<password_used_to_create_keystore>"

  ## Batcher configurations
  batcher:
    block_interval: 3
    batch_size_interval: 10
    max_proof_size: 67108864 # 64 MiB
    max_batch_size: 268435456 # 256 MiB
    eth_ws_reconnects: 99999999999999
    pre_verification_is_enabled: true

  ## Aggregator Configurations
  aggregator:
    server_ip_port_address: localhost:8090
    bls_public_key_compendium_address: 0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44
    avs_service_manager_address: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
    enable_metrics: true
    metrics_ip_port_address: localhost:9091

  ## Operator Configurations
  operator:
    aggregator_rpc_server_ip_port_address: localhost:8090
    address: <operator_account_address>
    earnings_receiver_address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    delegation_approver_address: "0x0000000000000000000000000000000000000000"
    staker_opt_out_window_blocks: 0
    metadata_url: "https://yetanotherco.github.io/operator_metadata/metadata.json"
    enable_metrics: true
    metrics_ip_port_address: localhost:9092
    max_batch_size: 268435456 # 256 MiB
  # Operators variables needed for register it in EigenLayer
  el_delegation_manager_address: "0xA44151489861Fe9e3055d95adC98FbD462B948e7"
  private_key_store_path: <home>/.eigenlayer/operator_keys/mina_bridge.ecdsa.key.json
  bls_private_key_store_path: <home>/.eigenlayer/operator_keys/mina_bridge.bls.key.json
  signer_type: local_keystore
  chain_id: 17000
  ```

1. Create `config-files/holesky/config-aggregator.yaml` and set it to:

  ```yaml
  # Common variables for all the services
  # 'production' only prints info and above. 'development' also prints debug
  environment: "production"
  aligned_layer_deployment_config_file_path: "./contracts/script/output/holesky/alignedlayer_deployment_output.json"
  eigen_layer_deployment_config_file_path: "./contracts/script/output/holesky/eigenlayer_deployment_output.json"
  eth_rpc_url: "https://holesky.internal.lambdaclass.com"
  eth_rpc_url_fallback: "https://holesky.internal.lambdaclass.com"
  eth_ws_url: "wss://ws.holesky.internal.lambdaclass.com"
  eth_ws_url_fallback: "wss://ws.holesky.internal.lambdaclass.com"
  eigen_metrics_ip_port_address: "localhost:9090"

  ## ECDSA Configurations
  ecdsa:
    private_key_store_path: "<home>/.eigenlayer/operator_keys/mina_bridge.ecdsa.key.json"
    private_key_store_password: "<password_used_to_create_keystore>"

  ## BLS Configurations
  bls:
    private_key_store_path: "<home>/.eigenlayer/operator_keys/mina_bridge.bls.key.json"
    private_key_store_password: "<password_used_to_create_keystore>"

  ## Aggregator Configurations
  aggregator:
    server_ip_port_address: localhost:8090
    bls_public_key_compendium_address: 0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44
    avs_service_manager_address: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
    enable_metrics: true
    metrics_ip_port_address: localhost:9091
  ```

1. Create `config-files/holesky/config-batcher.yaml` and set it to:

  ```yaml
  # Common variables for all the services
  # 'production' only prints info and above. 'development' also prints debug
  environment: "production"
  aligned_layer_deployment_config_file_path: "./contracts/script/output/holesky/alignedlayer_deployment_output.json"
  eigen_layer_deployment_config_file_path: "./contracts/script/output/holesky/eigenlayer_deployment_output.json"
  eth_rpc_url: "https://holesky.internal.lambdaclass.com"
  eth_rpc_url_fallback: "https://holesky.internal.lambdaclass.com"
  eth_ws_url: "wss://ws.holesky.internal.lambdaclass.com"
  eth_ws_url_fallback: "wss://ws.holesky.internal.lambdaclass.com"
  eigen_metrics_ip_port_address: "localhost:9090"

  ## ECDSA Configurations
  ecdsa:
    private_key_store_path: "<home>/.eigenlayer/operator_keys/mina_bridge.batcher.ecdsa.key.json"
    private_key_store_password: "<password_used_to_create_keystore>"

  ## Batcher configurations
  batcher:
    block_interval: 3
    batch_size_interval: 10
    max_proof_size: 67108864 # 64 MiB
    max_batch_size: 268435456 # 256 MiB
    eth_ws_reconnects: 99999999999999
    pre_verification_is_enabled: true
    non_paying:
      address: <batcher_account_address>
      replacement_private_key: <batcher_account_private_key>
  ```

1. Start the aggregator:

  ```sh
  make aggregator_start AGG_CONFIG_FILE=config-files/holesky/config-aggregator.yaml
  ```

1. Open a new terminal and register the operator:

  ```sh
  eigenlayer operator register config-files/holesky/config.yaml
  ```

1. Whitelist the registered operator:

  ```sh
  make operator_whitelist OPERATOR_ADDRESS=<operator_account_address>
  ```

1. Start operator:

  ```sh
  make operator_start CONFIG_FILE=config-files/holesky/config.yaml
  ```

1. Set `contracts/script/deploy/config/holesky/batcher-payment-service.holesky.config.json` to:

  ```json
  {
    "address": {
      "batcherWallet": "<batcher_account_address>",
      "alignedLayerServiceManager": "0x4d879A997f422FeB8AC2f3d9Dcc749e9d8d0E4a4"
    },
    "amounts": {
      "gasForAggregator": "300000",
      "gasPerProof": "21000"
    },
    "permissions": {
      "owner": "<operator_account_address>"
    },
    "eip712": {
      "noncedVerificationDataTypeHash": "41817b5c5b0c3dcda70ccb43ba175fdcd7e586f9e0484422a2c6bba678fdf4a3"
    }
  }
  ```

1. Deploy Batcher payment contract:

  ```sh
  make deploy_batcher_payment_service
  ```

  `contracts/script/output/holesky/alignedlayer_deployment_output.json` will have two new fields: `addresses.batcherPaymentService` and `addresses.batcherPaymentServiceImplementation`.

1. Pay the batcher:

  ```sh
  cast send <batcher_payment_service_address> --rpc-url https://holesky.internal.lambdaclass.com --private-key <batcher_account_private_key> --value 1ether
  ```

1. Deposit to batcher in the Aligned Service Manager Contract:

  ```sh
  cast send 0x4d879A997f422FeB8AC2f3d9Dcc749e9d8d0E4a4 --rpc-url https://holesky.internal.lambdaclass.com --private-key <batcher_account_private_key> --value 1ether "depositToBatcher(address)" <batcher_payment_service_address>
  ```

1. Start the batcher:

  ```sh
  cargo run --manifest-path ./batcher/aligned-batcher/Cargo.toml --release -- --config ./config-files/holesky/config-batcher.yaml --env-file ./batcher/aligned-batcher/.env
  ```

#### Bridge environment setup

In the Mina Bridge repo, setup the `.env` file. A template is available in `.env.template`.

1. Set `ETH_CHAIN` to `holesky`.
1. Set `MINA_RPC_URL` to the URL of the Mina node GraphQL API (See [Mina node section](#mina-node)).
1. Set the rest of the env vars to:

  ```sh
  BATCHER_ADDR="ws://localhost:8080"
  BATCHER_ETH_ADDR=<batcher_payment_service>
  ETH_RPC_URL=<url>
  PROOF_GENERATOR_ADDR=0x66f9664f97F2b50F62D13eA064982f936dE76657
  PRIVATE_KEY=<operator_account_private_key>
  ALIGNED_SM_HOLESKY_ETH_ADDR=0x4d879A997f422FeB8AC2f3d9Dcc749e9d8d0E4a4
  ```

### Bridge a Mina account

1. In the root folder, deploy the Bridge's contracts with:

    ```sh
    make deploy_contract
    ```
  
  In the `.env` file, set `STATE_SETTLEMENT_ETH_ADDR` and `ACCOUNT_VALIDATION_ETH_ADDR` to the corresponding deployed contract addresses.

1. Submit a Mina state proof to verify (**NOTE:** Because of the Aligned minimum batch size, you may need to submit two proofs to make Aligned Devnet verify them):

    ```sh
    make submit_state
    ```

1. Submit an account to verify (**NOTE:** Because of the Aligned minimum batch size, you may need to submit two proofs to make Aligned Devnet verify them):

    ```sh
    make submit_account PUBLIC_KEY=<string> STATE_HASH=<string>
    ```

    Where:
    - `PUBLIC_KEY` is the public key of the Mina account you want to verify
    - `STATE_HASH` is the hash of a Mina state that was verified in Ethereum

## Example use case

The `example/` folder contains a project that uses the Sudoku zkApp example from Mina and bridges its state to a SudokuValidity Ethereum smart contract.

For running the example you need to:

1. [Setup Aligned Devnet locally](https://github.com/yetanotherco/aligned_layer/blob/main/docs/guides/3_setup_aligned.md#booting-devnet-with-default-configs)
1. Deploy the bridge smart contracts by executing

    ```sh
    make deploy_contract
    ```

1. Deploy the SudokuValidity smart contract by executing

    ```sh
    make deploy_example_contract
    ```

1. Install `zkapp-cli`:

    ```sh
    npm install -g zkapp-cli
    ```

1. Inside the `example/mina_zkapp` directory, configure the zkApp and deploy the contract following [this guide](https://docs.minaprotocol.com/zkapps/writing-a-zkapp/introduction-to-zkapps/how-to-deploy-a-zkapp) on the Mina Protocol documentation

1. After deployment, set the `zkappAddress` field on `example/mina_zkapp/config.json`

1. Run the example by executing from the root folder:

    ```sh
    make execute_example
    ```

   this will upload a new Sudoku, submit a solution to it and run the example Rust app that will bridge the new state of the zkApp and update the SudokuValidty smart contract on Ethereum.

   The zkApp will wait until both Mina transactions are included in a block, so this may take a while. Below is a diagram explaining the execution flow:

![Example diagram](/img/example_diagram.png)

## Table of Contents

- [About](#about)
- [Usage](#usage)
- [Example use case](#example-use-case)
- [Table of Contents](#table-of-contents)
- [Specification](#specification)
  - [core](#core)
    - [mina](#mina)
    - [aligned](#aligned)
    - [eth](#eth)
  - [Mina Proof of State](#mina-proof-of-state)
    - [Definition](#definition)
    - [Serialization](#serialization)
    - [Aligned’s Mina Proof of State verifier](#aligneds-mina-proof-of-state-verifier)
    - [Consensus checking](#consensus-checking)
    - [Transition frontier](#transition-frontier)
    - [Pickles verification](#pickles-verification)
  - [Mina Proof of Account](#mina-proof-of-account)
    - [Definition](#definition-1)
    - [Serialization](#serialization-1)
    - [Aligned’s Proof of Account verification](#aligneds-proof-of-account-verifier)
  - [Smart contract](#smart-contract)
    - [Gas cost](#gas-cost)
  - [Mina Account Validation contract](#mina-account-validation-contract)
    - [Gas cost](#gas-cost-1)
- [Kimchi proving system](#kimchi-proving-system)
  - [Proof Construction & Verification](#proof-construction---verification)
    - [Secuence diagram linked to ``proof-systems/kimchi/src/verifier.rs``](#secuence-diagram-linked-to---proof-systems-kimchi-src-verifierrs--)
  - [Pickles - Mina’s inductive zk-SNARK composition system](#pickles---mina-s-inductive-zk-snark-composition-system)
    - [Accumulator](#accumulator)
    - [Analysis of the Induction (recursion) method applied in Pickles](#analysis-of-the-induction--recursion--method-applied-in-pickles)
    - [Pickles Technical Diagrams](#pickles-technical-diagrams)
  - [Consensus](#consensus)
    - [Chain selection rules](#chain-selection-rules)
      - [Short-range fork rule](#short-range-fork-rule)
      - [Long-range fork rule](#long-range-fork-rule)
    - [Decentralized checkpointing](#decentralized-checkpointing)
    - [Short-range fork check](#short-range-fork-check)
    - [Sliding window density](#sliding-window-density)
      - [Nomenclature](#nomenclature)
      - [Window structure](#window-structure)
      - [Minimum window density](#minimum-window-density)
      - [Ring-shift](#ring-shift)
      - [Projected window](#projected-window)
        - [Genesis window](#genesis-window)
        - [Relative minimum window density](#relative-minimum-window-density)
  - [Protocol](#protocol)
    - [Initialize consensus](#initialize-consensus)
    - [Select chain](#select-chain)
    - [Maintaining the k-th predecessor epoch ledger](#maintaining-the-k-th-predecessor-epoch-ledger)
    - [Getting the tip](#getting-the-tip)

# Specification

## core

[mina_bridge repo: core/](https://github.com/lambdaclass/mina_bridge/tree/aligned/core)

A Rust library+binary project that includes the next modules:

### mina

[mina_bridge repo: core/src/mina.rs](https://github.com/lambdaclass/mina_bridge/tree/aligned/core/src/mina.rs)

This module can query a Mina node (defined by the user via the `MINA_RPC_URL` env. variable) GraphQL DB for:

- state data and state proof
- account data and its Merkle proof of inclusion in some snarked ledger (which itself is contained in state data, so by verifying a state you are verifying its snarked ledger).

### aligned

[mina_bridge repo: core/src/aligned.rs](https://github.com/lambdaclass/mina_bridge/tree/aligned/core/src/aligned.rs)

This module implements functions for sending the Mina Proof of State or Account (retrieved by the **mina** module) to the Aligned batcher for verification, using the Aligned SDK. The batcher verifies the proof before including it in the current proof batch for then sending it to Aligned’s operators.

The verification data sent by Aligned is returned after proof submission. This is used for updating the verified chain in the State Settlement contract.

### eth

[mina_bridge repo: core/src/eth.rs](https://github.com/lambdaclass/mina_bridge/tree/aligned/core/src/eth.rs)

Implements functions for interacting with the bridge’s smart contracts on Ethereum (getters for storage variables, update the verified state chain, validate an account). Also includes code for deploying both contracts.

### sdk

[mina_bridge repo: core/src/sdk.rs](https://github.com/lambdaclass/mina_bridge/tree/aligned/core/src/sdk.rs)

Abstracts the previous modules to provide an easy way to verify states or accounts, and to retrieve storage data from the State Settlement contract.

## Mina Proof of State

### Definition

We understand a Mina Proof of State to be composed of:

- **public inputs**:

```rust
[
/// The hash of the bridge's transition frontier tip state. Used for making sure that we're
/// checking if a candidate tip is better than the latest bridged tip.
bridge_tip_state_hash,

/// The state hashes of the candidate chain.
candidate_chain_state_hashes[16],

/// The ledger hashes of the candidate chain. The ledger hashes are the root of a Merkle tree
/// where the leafs are Mina account hashes. Used for account verification.
candidate_chain_ledger_hashes[16],
]
```

- **proof**:

```rust
[
/// The state proof of the tip state (latest state of the chain, or "transition frontier"). If
/// this state is valid, then all previous states are valid thanks to Pickles recursion.
candidate_tip_proof,

/// The state data of the candidate chain. Used for consensus checks and checking that the
/// public input state hashes correspond to states that effectively form a chain.
candidate_chain_states,

/// The latest state of the previously bridged chain, the latter also called the bridge's
/// transition frontier. Used for consensus checks needed to be done as part of state
/// verification to ensure that the candidate tip is better than the bridged tip.
bridge_tip_state,
]
```

### Serialization

We use **bincode** for serializing the data into bytes, which will then be deserialized by Aligned operators. Because the public inputs also need to be deserialized in Solidity, the module defines a `SolSerialize` struct that implements traits for serializing specific types into a Solidity-friendly format (the goal is to be able to serialize the types the same way they’re represented in the EVM and move them from calldata to memory via single Yul instructions).

### Aligned’s Mina Proof of State verifier

[aligned_layer repo: operator/mina/](https://github.com/lambdaclass/aligned_layer/tree/mina/operator/mina)

Aligned Layer integrated a verifier in its operator code for verifying Mina Proofs of State.

### Public input checking

The first step of the verifier is to check that the public inputs correspond to the proof data. This is:

- that the bridge tip state hash is the actual hash of the latest bridged tip state
- that the chain state hashes are the hashes of the states in the proof
- that the chain ledger hashes are the hashes of the ledgers (stored in the states) in the proof
- that the states form a chain (by hashing together the **state hash** of a state `n` and the **state body hash** of state `n+1`, we retrieve the **state hash** of the state `n+1`, so the states form a chain if we can hash from the root all the way until arriving to the tip state hash.

### Consensus checking

The second step of the verifier is to execute consensus checks, specific to the [Ouroboros Samasika consensus mechanism](https://github.com/MinaProtocol/mina/blob/develop/docs/specs/consensus/README.md) that the Mina Protocol uses. The checks are comparisons of state data between the candidate tip state and the bridge tip state.

There are two general rules that implement a set of checks each: a rule for short-range forks, and another for long-range forks. The implementation can be found in the [aligned_layer repo: operator/mina/lib/src/consensus_state.rs](https://github.com/lambdaclass/aligned_layer/blob/consensus_state_input_checks/operator/mina/lib/src/consensus_state.rs) file. The implementation was based on the official [Mina Protocol consensus documentation](https://github.com/MinaProtocol/mina/blob/develop/docs/specs/consensus/README.md).

### Transition frontier

The **transition frontier** is a chain of the latest `k` blocks of the network. The GraphQL DB of a Mina node only stores these blocks and forgets the previous ones. Currently, `k = 291`

It's not so rare for two or more nodes to generate blocks simultaneously, resulting in temporary forks of the network. The network will eventually resolve the forks after a period of time. Because of these phenomenon some blocks might not be **final** (part of the canonical chain).

We can define that a block is **partially finalized** if it has `n` blocks ahead of it, with `n` being the number defined for 'partial finalization'. For the bridge we settled with `n = 15`, so the State Settlement contract will store a chain of `16` validated blocks.

A block is **finalized** when there’s `k - 1` blocks ahead of it., meaning that it’s the first block of the transition frontier, also called the **root block**. The latest block of the transition frontier is called the **tip**.

### Pickles verification

This is the last step of the Mina Proof of State verifier. We are leveraging OpenMina’s “block verifier” to verify the Pickles proof of the candidate tip state. The verifier takes as public input the hash of the state.

After validating the candidate tip state, because in a previous step we verified that there’s a chain of `n` candidate blocks with a valid tip, and because of the built-in recursion of the Pickles composition system (each state validates the previous one), we end up validating the whole state chain.

> [!WARNING]
> OpenMina’s block verifier is yet to be audited.

## Mina Proof of Account

After a Mina Proof of State was verified, it’s possible to verify a Proof of Account of some Mina account in the verified state.

Verifying that some account and its state is valid in a bridged Mina state is one of the basic components of a Mina to Ethereum bridge, as it not only allows to validate account data but also the state of a [zkApp](https://docs.minaprotocol.com/zkapps/writing-a-zkapp) tracked by this account (see [zkApp Account](https://docs.minaprotocol.com/glossary#zkapp-account)), which leverages zk-SNARKs to verify (optionally private) off-chain computation on the Mina blockchain.

Account verification (paired with state verification) essentially allows to verify off-chain computation on Ethereum, after it has been validated by Mina.

### Definition

We understand a Mina Proof of Account to be composed of:

- **public inputs**:

```rust
[
/// Hash of the snarked ledger that this account state is included on
ledger_hash,
/// ABI encoded Mina account (Solidity structure)
encoded_account
]
```

- **proof**:

```rust
[
/// Merkle path between the leaf hash (account hash) and the merkle root (ledger hash)
merkle_path,
/// The Mina account (OpenMina structure)
account
]
```

The account is included in the proof to:

- compare it with the Solidity-friendly `encoded_account` in the public inputs
- hash it to retrieve the leaf hash of the Merkle tree to verify

### Serialization

We use **bincode** for serializing the data into bytes, which will then be deserialized by Aligned operators. Because the public inputs also need to be deserialized in Solidity, the module defines a `SolSerialize` struct that implements traits for serializing specific types into a Solidity-friendly format (the goal is to be able to serialize the types the same way they’re represented in the EVM and move them from calldata to memory via single Yul instructions).

### Aligned’s Proof of Account verification

[aligned_layer repo: operator/mina_account/](https://github.com/lambdaclass/aligned_layer/tree/mina/operator/mina_account)

The verification consists in calculating the merkle root by hashing the branch (whose nodes are contained in the `merkle_path`) corresponding to the account’s leaf, and comparing the root with the snarked ledger hash included in the public inputs.

## Mina State Settlement contract

[mina_bridge repo: contract/src/MinaStateSettlement.sol](https://github.com/lambdaclass/mina_bridge/tree/aligned/contract/src/MinaStateSettlement.sol)

This contract stores the latest verified state and ledger hashes (also called the bridge’s transition frontier) and updates the arrays with new values whenever a new Mina Proof of State is submitted.

Any user can submit a Mina Proof of State to Aligned and then provide the contract with the verification data for updating its storage. The contract calls the Aligned Service Manager to check that the proof was indeed verified.

The contract is deployed by a `contract_deployer` crate with an initial state that is assumed to be valid. The default is to use a relatively finalized state (the sixteenth one) from the Mina node chosen to execute the query to.

### Gas cost

- Currently the cost of the “update chain” transaction is ~220k.

## Mina Account Validation contract

[mina_bridge repo: contract/src/MinaAccountValidation.sol](https://github.com/lambdaclass/mina_bridge/tree/aligned/contract/src/MinaAccountValidation.sol)

This contract implements a method for validating an account, taking as parameter the verification data and public inputs of the proof sent to Aligned. It also implements a structure for representing account data. A user can decode the account from the public inputs into this structure.

Any user can submit a Mina Proof of Account to Aligned and then provide the contract with the verification data for checking on-chain that the account was validated. The contract calls the Aligned Service Manager to check that the proof was indeed verified.

The contract is deployed by a `contract_deployer` crate.

### Gas cost

- The cost of the “update account” transaction is ~80k.

# Kimchi proving system

Kimchi is a zero-knowledge proof system that’s a variant of PLONK.

Kimchi represents a series of enhancements, optimizations, and modifications implemented atop PLONK. To illustrate, it addresses PLONK's trusted setup constraint by incorporating a polynomial commitment in a bulletproof-style within the protocol. In this manner, there's no necessity to rely on the honesty of the participants in the trusted setup.

Kimchi increases PLONK's register count from 3 to 15 by adding 12 registers.
With an increased number of registers, Kimchi incorporate gates that accept multiple inputs, as opposed to just two. This unveils new opportunities; for instance, a scalar multiplication gate would necessitate a minimum of three inputs—a scalar and two coordinates for the curve point.

New proof systems resembling PLONK employ custom gates to efficiently represent frequently used functionalities, as opposed to connecting a series of generic gates. Kimchi is among these innovative protocols.

In Kimchi, there's a concept where a gate has the ability to directly record its output onto the registers utilized by the subsequent gate.

Another enhancement in Kimchi involves the incorporation of lookups for performance improvement. Occasionally, certain operations can be expressed in a tabular form, such as an XOR table.

In the beginning, Kimchi relies on an interactive protocol, which undergoes a conversion into a non-interactive form through the Fiat-Shamir transform.

## Proof Construction & Verification

### Secuence diagram linked to ``proof-systems/kimchi/src/verifier.rs``

![Commitments to secret polynomials](/img/commitments_to_secret_poly.png)

Links to the associated code.

[public input & witness commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L134)

[beta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L196)

[gamma](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L199)

[permutation commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L206)

---

![Commitments to quotient polynomials](/img/commitments_to_quotient_poly.png)

Links to the associated code.

[alpha](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L213)

[quotient commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L221)

---

![Verifier produces an evaluation point](/img/verifier_produces_evaluation_point.png)

Links to the associated code.

[zeta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L227)

[change of sponge](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L234)

[recursion challenges](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L236)

---

![Prover provides needed evaluations for the linearization - 1](/img/prover_provides_evaluations_linearization_01.png)

Links to the associated code.

[zeta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L227)

[negated public input](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L290)

[15 register/witness - 6 sigmas evaluations](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L323)

---

![Prover provides needed evaluations for the linearization - 2](/img/prover_provides_evaluations_linearization_02.png)

Links to the associated code.

TODO

---

![Batch verification of evaluation proofs](/img/batch_verification_evaluation_proofs.png)

Links to the associated code.

[v,u](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L334)

[polynomials that have an evaluation proof](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L346)

## Pickles - Mina’s inductive zk-SNARK composition system

Pickles uses a pair of amicable curves called [Pasta](https://o1-labs.github.io/proof-systems/specs/pasta.html) in order to deliver incremental verifiable computation efficiently.

The two curves pallas and vesta (pa(llas ve)sta) created by the [Zcash team](https://github.com/zcash/pasta?tab=readme-ov-file#pallasvesta-supporting-evidence). Each curve’s scalar field is the other curve’s base field, which is practical for recursion

These curves are referred to as “tick” and “tock” within the Mina source code.

- Tick - Vesta (a.k.a. Step), constraint domain size 2¹⁸  [block and transaction proofs]
- Tock - Pallas (a.k.a. Wrap), constraint domain size 2¹²  [signatures]

The Tock prover does less (only performs recursive verifications and
no other logic), so it requires fewer constraints and has a smaller
domain size.  Internally Pickles refers to Tick and Tock as _Step_ and
_Wrap_, respectively.

One curve handles the current proof, while the other is used to verify previous proofs.

Tock is used to prove the verification of a Tick proof and outputs a
Tick proof.  Tick is used to prove the verification of a Tock proof and
outputs a Tock proof.  In other words,

- Prove_tock ( Verify(_Tick_) ) = Tick_proof

- Prove_tick (Verify(_Tock_) ) = Tock_proof

![Description](/img/palas_vesta.png)

Both Tick and Tock can verify at most 2 proofs of the opposite kind, though, theoretically more is possible.

Currently, in Mina we have the following situation.

- Every Tock always wraps 1 Tick proof.  
- Tick proofs can verify 2 Tock proofs
  - Blockchain SNARK takes previous blockchain SNARK proof and a transaction proof
  - Verifying two Tock transaction proofs

Pickles works over [Pasta](https://o1-labs.github.io/proof-systems/specs/pasta.html), a cycle of curves consisting of Pallas and Vesta, and thus it defines two generic circuits, one for each curve. Each can be thought of as a parallel instantiation of a kimchi proof systems. These circuits are not symmetric and have somewhat different function:

- **Step circuit**: this is the main circuit that contains application logic. Each step circuit verifies a statement and potentially several (at most 2) other wrap proofs.
- **Wrap circuit**: this circuit merely verifies the step circuit, and does not have its own application logic. The intuition is that every time an application statement is proven it’s done in Step, and then the resulting proof is immediately wrapped using Wrap.

---

Both [Step and Wrap circuits](https://o1-labs.github.io/proof-systems/pickles/overview.html#general-circuit-structure) additionally do a lot of recursive verification of the previous steps. Without getting too technical, Step (without loss of generality) does the following:

1. Execute the application logic statement (e.g. the mina transaction is valid)
2. Verify that the previous Wrap proof is (first-)half-valid (perform only main checks that are efficient for the curve)
3. Verify that the previous Step proof is (second-)half-valid (perform the secondary checks that were inefficient to perform when the previous Step was Wrapped)
4. Verify that the previous Step correctly aggregated the previous accumulator, e.g. acc2=Aggregate(acc1,_π_ step,2)

![Step-Wrap Diagram](/img/step_diagram.png)

---

### Accumulator

The accumulator is an abstraction introduced for the purpose of this diagram. In practice, each kimchi proof consists of (1) commitments to polynomials, (2) evaluations of them, (3) and the opening proof.

What we refer to as **accumulator** here is actually the commitment inside the opening proof. It is called `sg` in the implementation and is semantically a polynomial commitment to `h(X)` (`b_poly` in the code) — the poly-sized polynomial that is built from IPA challenges.

It’s a very important polynomial – it can be evaluated in log time, but the commitment verification takes poly time, so the fact that `sg` is a commitment to `h(X)` is never proven inside the circuit. For more details, see [Proof-Carrying Data from Accumulation Schemes](https://eprint.iacr.org/2020/499.pdf), Appendix A.2, where `sg` is called `U`.

In pickles, what we do is that we “absorb” this commitment `sg` from the previous step while creating a new proof.

That is, for example, Step 1 will produce this commitment that is denoted as `acc1` on the diagram, as part of its opening proof, and Step 2 will absorb this commitment. And this “absorbtion” is what Wrap 2 will prove (and, partially, Step 3 will also refer to the challenges used to build `acc1`, but this detail is completely avoided in this overview). In the end, `acc2` will be the result of Step 2, so in a way `acc2` “aggregates” `acc1` which somewhat justifies the language used.

### Analysis of the Induction (recursion) method applied in Pickles

The **Verifier** is divided into 2 modules, one part **Slow** and one part **Fast**.

![Figure 1](/img/pickles_step_01.png)

**S0** is the initial statement, **U** is the Update algorithm, the **Pi** are the proofs, and the **S's** are the updated statements.

![Figure 2](/img/pickles_step_02.png)

On top of each **Pi** proof, we run a **Fast** verifier. With the **Pi** proof and the cumulative Statement from the previous step, the **U** algorithm is applied and a new updated Statement is created. This _new updated Statement_ is the input of the Slow part of the Verifier, but we don't run the Slow Verifier until we reach the end of the whole round.

---
Execution of **Verifier Slow** (which is very slow) can be **deferred** in sequences, and the V slow current always accumulates to the previous statement. This implicitly 'runs Vs on S1' as well.

---

Remember that the S's are statements that accumulate, so each one has information from the previous ones.

![Figure 3](/img/pickles_step_03.png)

When we reached the last round we see that the intermediate Verifiers Slow disappears, as they are no longer useful to us.

![Figure 4](/img/pickles_step_04.png)

Attention!! We haven't executed any Verifier Slow yet; we only run Verifier Fast in each round.

Therefore, in the last step, we execute the current **Verifier Fast** on its Pi, and the **Last Verifier Slow** on the **Final S**. This may take 1 second, but it accumulates all the previous ones.

![Figure 5](/img/pickles_step_05.png)

---

Everything inside the large red square in the following figure has already been processed by the time we reach the last round.

![Figure 6](/img/pickles_step_06.png)

---

Let's now see how the Verifier Fast is divided.

![Figure 7](/img/pickles_step_07.png)

**Vf** corresponds to field operations in a field **F**, and **Vg** corresponds to group operations in a group **G**.

![Figure 8](/img/pickles_step_08.png)

The proof **Pi** is divided into 2 parts, one corresponding to group operations **G**, and it exposes, as a public input to the circuit, the part of the proof that is necessary to execute **Vf**.

### Pickles Technical Diagrams

  The black boxes are data structures that have names and labels following the implementation.  
  `MFNStep/MFNWrap` is an abbreviation from `MessagesForNextStep` and `MessagesForNextWrap` that is used for brevity. Most other datatypes are exactly the same as in the codebase.  

  The blue boxes are computations. Sometimes, when the computation is trivial or only vaguely indicated, it is denoted as a text sign directly on an arrow.

  Arrows are blue by default and denote moving a piece of data from one place to another with no (or very little) change. Light blue arrows are denoting witness query that is implemented through the handler mechanism. The “chicken foot” connector means that this arrow accesses just one field in an array: such an arrow could connect e.g. a input field of type old_a: A in a structure Vec<(A,B)> to an output new_a: A, which just means that we are inside a for loop and this computation is done for all the elemnts in the vector/array.

![Figure](/img/pickles_structure_drawio.png)

## Consensus

Mina employs [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) as its consensus mechanism, which will be subsequently denoted as Samasika.
Three essential commitments provided include:

- High decentralization - Self-bootstrap, uncapped participation and dynamic availability
- Succinctness - Constant-time synchronization with full-validation and high interoperability
- Universal composability - Proven security for interacting with other protocols, no slashing required

Joseph Bonneau, Izaak Meckler, Vanishree Rao, and Evan Shapiro collaborated to create Samasika, establishing it as the initial succinct blockchain consensus algorithm.  
The complexity of fully verifying the entire blockchain is independent of chain length.  
Samasika takes its name from the Sanskrit term, meaning small or succinct.

### Chain selection rules

Samasika uses two consensus rules: one for _short-range forks_ and one for _long-range forks_.

#### Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.  
A fork is considered short-range if it took place within the last **m** blocks. The straightforward implementation of this rule involves consistently storing the most recent **m** blocks. Yet, in the context of a succinct blockchain, this is considered not desirable. Mina Samasika follows a methodology that necessitates information about only two blocks, the concept involves a decentralized checkpointing algorithm.

#### Long-range fork rule

When a malicious actor generates an long-range fork, it gradually distorts the leader selection distribution, resulting in a longer adversarial chain. At the start, the dishonest chain will have a reduced density, but eventually, the adversary will work to elevate it. Therefore, the only factor we can depend on is the variation in density in the initial slots after the fork, which is known as the _critical window_.  
The reasoning is that the critical window of the honest chain is very likely to have a higher density because this chain has the most stake

### Decentralized checkpointing

Samasika employs decentralized checkpointing to discern the nature of a fork, categorizing it as either short-range or long-range.

- **Start checkpoint** - State hash of the first block of the epoch.
- **Lock checkpoint** - State hash of the last known block in the seed update range of an epoch (not including the current block)

Remember, a fork is categorized as short-range if either:

- The fork point of the candidate chains are in the same epoch.
- The fork point is in the previous epoch with the same ``lock_checkpoint``

As Mina prioritizes succinctness, it implies the need to maintain checkpoints for both the current and the previous epoch.

### Short-range fork check

Keep in mind that short-range forks occur when the fork point occurs after the lock_checkpoint of the previous epoch; otherwise, it qualifies as a long-range fork.  
The position of the previous epoch is a measurement relative to a block's perspective. In cases where candidate blocks belong to distinct epochs, each will possess distinct current and previous epoch values.  
Alternatively, if the blocks belong to the same epoch, they will both reference the identical previous epoch. Thus we can simply check whether the blocks have the same lock_checkpoint in their previous epoch data.

### Sliding window density

Let describe Mina's succinct sliding window density algorithm used by the long-range fork rule. In detail how windows are represented in blocks and how to compute _minimum window density_

#### Nomenclature

- We say a slot is _filled_ if it contains a valid non-orphaned block.
- An _w-window_ is a sequential list of slots s1,...,sw of length _w_.
- A _sub-window_ is a contiguous interval of a _w-window_.
- The _density_ of an w-window (or sub-window) is the number non-orphan block within it.
- We use the terms _window_, _density window_, _sliding window_ and _w-window_ synonymously.
- v is the Length by which the window shifts in slots (shift parameter).  ``slots_per_sub_window``
- w is the Window length in slots.  ( the sliding window is a _w_-long window that shifts _v_-slots at a time).

The Samasika research paper presents security proofs that determine the secure values for v, w, and sub-windows per window.  
A sliding window can also be viewed as a collection of _sub-windows_.  
Rather than storing a window as clusters of slots, Samasika focuses solely on the density of each sub-window.  
The density of a window is computed as the sum of the densities of its sub-windows.

Given a window ``W`` that is a list of sub-window densities, the window density is: ``density(W) = sum(W)``

#### Window structure

We use the phrase "window at sub-window _s_" to refer to the window _W_ whose most recent global sub-window is _s_.  
In the Samasika paper the window structure actually consists of the **11 previous sub-window densities**, the **current sub-window density** and the **minimum window density** .A total of _13_ densities.  
The most recent sub-window may be a previous sub-window or the current sub-window.  

#### Minimum window density

The **minimum window density** at a given slot is defined as the minimum window density observed over all previous sub-windows and previous windows, all the way back to genesis.  
When a new block _B_ with parent _P_ is created, the minimum window density is computed like this.  
``B.min_window_density = min(P.min_window_density, current_window_density)``  
where ``current_window_density`` is the density of _B's_ projected window

The relative sub-window _i_ of a sub-window _sw_ is its index within the window.

#### Ring-shift

When we shift a window ``[d0, d1, ..., d10]`` in order to add in a new sub-window ``d11``, we could evict the oldest sub-window d0 by shifting down all of the other sub-windows. Unfortunately, shifting a list in a SNARK circuit is very expensive.  
It is more efficient (and also equivalent) to just replace the sub-window we wish to evict by overwriting it with the new sub-window, like this:
 ``sub_window_densities: d11 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10``

#### Projected window

Generating a new block and determining the optimal chain in accordance with the long-range fork rule involve the computation of a projected window.  
Given a window _W_ and a future global slot _next_, the projected window of _W_ to slot _next_ is a transformation of _W_ into what it would look like if it were positioned at slot _next_.  
For example, when a new block _B_ is produced with parent block _P_, the height of _B_ will be the height of _P_ plus one, but the global slot of _B_ will depend on how much time has elapsed since _P_ was created.  
According to the Samasika paper, the window of _B_ must be initialized based on _P's_ window, then shifted because _B_ is ahead of _P_ and finally the value of _B's_ sub-window is incremented to account for _B_ belonging to it.  
Remember that the calculation of window density, including sub-window s, only occurs when the sub-window is greater than s, after s becomes a previous sub-window.
Therefore, if _next_ is **k** sub-windows ahead of _W_ we must shift only **k - 1** times because we must keep the most recent previous sub-window.

Now that we know how much to ring-shift, the next question is what density values to shift in. Remember that when projecting W to global slot next, we said that there are no intermediate blocks. That is, all of the slots and sub-windows are empty between W's current slot and next. Consequently, we must ring-shift in zero densities. The resulting window W is the projected window.

Recall this diagram:

![consensus01](/img/consensus01.png)

Suppose window W's current sub-window is 11 whose density is d11 and d1 is the oldest sub-window density

Now imagine we want to project W to global slot ``next = 15``. This is ``k = 15 - 11 = 4`` sub-windows ahead of the most recent sub-window. Therefore, we compute ``shift_count = min(max(k - 1, 0), sub_windows_per_window)``  in this case: ``shift_count = min(max(4 - 1, 0), 11) = 3``

Ring-shift in 3 zero densities to obtain the projected window.

![consensus02](/img/consensus02.png)

We can derive some instructive cases from the general rule

![consensus03](/img/consensus03.png)

##### Genesis window

Anything related to Genesis windows is not involved in the Mina Bridge.

##### Relative minimum window density

When Mina engages "chain selection" in the long-range fork rule, It doesn't directly employ the minimum window densities found in  in the current and candidate blocks.  
Rather than that, Mina opts for the relative minimum window density...

Remember that the minimum window density consistently decreases. Consequently, if a peer has been offline for a while and wants to reconnect, their current best chain might exhibit a higher minimum window density compared to the canonical chain candidate.
Additionally, the long-range fork rule dictates that the peer to choose the chain with the superior minimum density.  
The calculation of the minimum window density does not take into account the relationship between the current best chain and the canonical chain with respect to time.  
Within Samasika, time is encapsulated and safeguarded by the notions of slots and the VRF. When computing the minimum window density, it is imperative to factor in these elements as well.  
The relative minimum window density solves this problem by projecting the joining peer's current block's window to the global slot of the candidate block.  

## Protocol

This section outlines the consensus protocol in terms of events. **Initialize consensus** and **Select chain**.

In the following description, dot notation is used to refer to the local data members of peers. For example, given peer P, we use P.genesis_block and P.tip, to refer to the genesis block and currently selected chain, respectively.  
For example, given peer ``P``, we use ``P.genesis_block`` and ``P.tip``, to refer to the genesis block and currently selected chain, respectively.

### Initialize consensus

Things a peer MUST do to initialize consensus includes are _Load the genesis block_, _Get the tip_, _Bootstrap_ and _Catchup_  
Bootstrapping consensus requires the ability to synchronize epoch ledgers from the network.  
All peers MUST have the ability to load both the staking epoch ledger and next epoch ledger from disk and by downloading them. P2P peers MUST also make these ledgers available for other peers.  

### Select chain

Each time a peer's chains receive an update, the select chain event takes place.  
A chain is said to be updated anytime a valid block is added or removed from its head. The chain selection algorithm also incorporates certain tiebreak logic.  
Supplementary tiebreak logic becomes necessary when assessing chains with identical length or equal minimum density.

Let ``P.tip`` refer to the top block of peer ``P``'s current best chain. Assuming an update to either ``P.tip`` or ``P.chains``, ``P`` must update its tip similar to this:

![consensus06](/img/consensus06.png)

The following selectSecureChain algorithm receives the peer's current best chain P.tip and its set of known valid chains P.chains and produces the most secure chain as output.  

![consensus07](/img/consensus07.png)

And the ``selectLongerChain`` algorithm:

![consensus08](/img/consensus08.png)

### Maintaining the k-th predecessor epoch ledger

The staking and next epoch ledgers MUST be finalized ledgers and can only advance when there is sufficient depth to achieve finality.  
The staking and next epoch ledgers must be in a finalized state and can progress only when there is enough depth to ensure finality. Peers are required to retain the epoch ledger of the k-th predecessor from the tip, where ``k`` represents the depth of finality.  
Due to the security prerequisites of Ouroboros, the gap in slots between the staking and next epoch ledgers may be great. Consequently, at any given moment, we essentially have three "pointers": staking ``s``, next ``n``, and finality ``k``.  
The ``final_ledger`` (epoch ledger of the k-th predecessor from the tip) is updated each time chain selection occurs, i.e., for every new tip block appended.  

### Getting the tip

For a joining peer to discover the head of the current chain it MUST not only obtain the tip, but also the min(k, tip.height - 1)-th block back from the tip. For the latter the peer MUST check the block's proof of finality.  
Peers perform the proof of finality check by verifying two zero-knowledge proofs, one for the _tip_ and one for the _root_, and a Merkle proof for the chain of protocol state hashes between them.
