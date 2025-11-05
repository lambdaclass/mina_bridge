// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error MinaProvingSystemIdIsNotValid(bytes32); // c35f1ecd
error MinaNetworkIsWrong(); // 042eb0cf
error NewStateIsNotValid(); // 114602f0
error TipStateIsWrong(bytes32 pubInputTipStateHash, bytes32 tipStatehash); // bbd80128
error AccountIsNotValid(bytes32 accountIdHash);

/// @title Mina to Ethereum Bridge's smart contract for verifying and storing a valid state chain.
/// WARNING: This contract is meant ot be used as an example of how to use the Bridge.
/// NEVER use this contract in a production environment.
contract MinaStateSettlementExample {
    /// @notice The commitment to Mina proving system ID.
    bytes32 constant PROVING_SYSTEM_ID_COMM = 0xd0591206d9e81e07f4defc5327957173572bcd1bca7838caa7be39b0c12b1873;

    /// @notice The length of the verified state chain (also called the bridge's transition
    /// frontier) to store.
    uint256 public constant BRIDGE_TRANSITION_FRONTIER_LEN = 16;

    /// @notice The state hash of the last verified chain of Mina states (also called
    /// the bridge's transition frontier).
    bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] chainStateHashes;
    /// @notice The ledger hash of the last verified chain of Mina states (also called
    /// the bridge's transition frontier).
    bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] chainLedgerHashes;

    bool devnetFlag;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address payable _alignedServiceAddr, bytes32 _tipStateHash, bool _devnetFlag) {
        aligned = AlignedLayerServiceManager(_alignedServiceAddr);
        chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1] = _tipStateHash;
        devnetFlag = _devnetFlag;
    }

    /// @notice Returns the last verified state hash.
    function getTipStateHash() external view returns (bytes32) {
        return chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1];
    }

    /// @notice Returns the last verified ledger hash.
    function getTipLedgerHash() external view returns (bytes32) {
        return chainLedgerHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1];
    }

    /// @notice Returns the latest verified chain state hashes.
    function getChainStateHashes() external view returns (bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] memory) {
        return chainStateHashes;
    }

    /// @notice Returns the latest verified chain ledger hashes.
    function getChainLedgerHashes() external view returns (bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] memory) {
        return chainLedgerHashes;
    }

    /// @notice Returns true if this snarked ledger hash was bridged.
    function isLedgerVerified(bytes32 ledgerHash) external view returns (bool) {
        for (uint256 i = 0; i < BRIDGE_TRANSITION_FRONTIER_LEN; i++) {
            if (chainLedgerHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1 - i] == ledgerHash) {
                return true;
            }
        }
        return false;
    }

    function updateChain(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes memory pubInput,
        address batcherPaymentService
    ) external {
        if (provingSystemAuxDataCommitment != PROVING_SYSTEM_ID_COMM) {
            revert MinaProvingSystemIdIsNotValid(provingSystemAuxDataCommitment);
        }

        bool pubInputDevnetFlag = pubInput[0] == 0x01;

        if (pubInputDevnetFlag != devnetFlag) {
            revert MinaNetworkIsWrong();
        }

        bytes32 pubInputBridgeTipStateHash;
        assembly {
            pubInputBridgeTipStateHash := mload(add(pubInput, 0x21)) // Shift 33 bytes (32 bytes length + 1 byte Devnet flag)
        }

        if (pubInputBridgeTipStateHash != chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]) {
            revert TipStateIsWrong(pubInputBridgeTipStateHash, chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]);
        }

        bytes32 pubInputCommitment = keccak256(pubInput);

        bool isNewStateVerified = aligned.verifyBatchInclusion(
            proofCommitment,
            pubInputCommitment,
            provingSystemAuxDataCommitment,
            proofGeneratorAddr,
            batchMerkleRoot,
            merkleProof,
            verificationDataBatchIndex,
            batcherPaymentService
        );

        if (isNewStateVerified) {
            // store the verified state and ledger hashes
            assembly {
                let slot_states := chainStateHashes.slot
                let slot_ledgers := chainLedgerHashes.slot

                // first 32 bytes is length of byte array.
                // the next byte is the Devnet flag
                // the next 32 bytes set is the bridge tip state hash
                // the next BRIDGE_TRANSITION_FRONTIER_LEN sets of 32 bytes are state hashes.
                let addr_states := add(pubInput, 65)
                // the next BRIDGE_TRANSITION_FRONTIER_LEN sets of 32 bytes are ledger hashes.
                let addr_ledgers := add(addr_states, mul(32, BRIDGE_TRANSITION_FRONTIER_LEN))

                for { let i := 0 } lt(i, BRIDGE_TRANSITION_FRONTIER_LEN) { i := add(i, 1) } {
                    sstore(slot_states, mload(addr_states))
                    addr_states := add(addr_states, 32)
                    slot_states := add(slot_states, 1)

                    sstore(slot_ledgers, mload(addr_ledgers))
                    addr_ledgers := add(addr_ledgers, 32)
                    slot_ledgers := add(slot_ledgers, 1)
                }
            }
        } else {
            revert NewStateIsNotValid();
        }
    }
}
