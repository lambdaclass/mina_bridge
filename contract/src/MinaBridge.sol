// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();
error TipStateIsWrong(bytes32 pubInputTipStateHash, bytes32 tipStatehash);
error AccountIsNotValid(bytes32 accountIdHash);

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The length of the verified state chain (also called the bridge's transition
    /// frontier) to store.
    uint public constant BRIDGE_TRANSITION_FRONTIER_LEN = 16;

    /// @notice The state hash of the last verified chain of Mina states (also called
    /// the bridge's transition frontier).
    bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] chainStateHashes;
    /// @notice The ledger hash of the last verified chain of Mina states (also called
    /// the bridge's transition frontier).
    bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] chainLedgerHashes;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address _alignedServiceAddr, bytes32 _tipStateHash) {
        aligned = AlignedLayerServiceManager(_alignedServiceAddr);
        chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1] = _tipStateHash;
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
    function getChainStateHashes()
        external
        view
        returns (bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] memory)
    {
        return chainStateHashes;
    }

    /// @notice Returns the latest verified chain ledger hashes.
    function getChainLedgerHashes()
        external
        view
        returns (bytes32[BRIDGE_TRANSITION_FRONTIER_LEN] memory)
    {
        return chainLedgerHashes;
    }

    function updateChain(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes memory pubInput
    ) external {
        bytes32 pubInputBridgeTipStateHash;
        assembly {
            pubInputBridgeTipStateHash := mload(add(pubInput, 0x20))
        }

        if (
            pubInputBridgeTipStateHash !=
            chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]
        ) {
            revert TipStateIsWrong(
                pubInputBridgeTipStateHash,
                chainStateHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]
            );
        }

        bytes32 pubInputCommitment = keccak256(pubInput);

        bool isNewStateVerified = aligned.verifyBatchInclusion(
            proofCommitment,
            pubInputCommitment,
            provingSystemAuxDataCommitment,
            proofGeneratorAddr,
            batchMerkleRoot,
            merkleProof,
            verificationDataBatchIndex
        );

        if (isNewStateVerified) {
            // store the verified state and ledger hashes
            assembly {
                let slot_states := chainStateHashes.slot
                let slot_ledgers := chainLedgerHashes.slot

                // first 32 bytes is length of byte array.
                // second 32 bytes is the bridge tip state hash
                // the next BRIDGE_TRANSITION_FRONTIER_LEN sets of 32 bytes are state hashes.
                let addr_states := add(pubInput, 64)
                // the next BRIDGE_TRANSITION_FRONTIER_LEN sets of 32 bytes are ledger hashes.
                let addr_ledgers := add(
                    addr_states,
                    mul(32, BRIDGE_TRANSITION_FRONTIER_LEN)
                )

                for {
                    let i := 0
                } lt(i, BRIDGE_TRANSITION_FRONTIER_LEN) {
                    i := add(i, 1)
                } {
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
