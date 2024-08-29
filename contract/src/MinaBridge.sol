// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";
import "./Account.sol";

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

    /// @notice mapping of a keccak256(TokenId) => verified account hash and its ledger hash.
    mapping(bytes32 => Account.LedgerAccountPair) accounts;

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

    /// @notice Returns the ledger hash and account state hash pair for
    //  a given account id.
    function getLedgerAccountPair(
        bytes32 accountIdHash
    ) external view returns (Account.LedgerAccountPair memory) {
        return accounts[accountIdHash];
    }

    /// @notice Checks if some account state is verified for the latest
    //  verified Mina state.
    function isAccountUpdated(
        bytes32 accountIdHash
    ) external view returns (bool) {
        return
            accounts[accountIdHash].ledgerHash ==
            chainLedgerHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1];
    }

    function updateTipState(
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
            chainLedgerHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]
        ) {
            revert TipStateIsWrong(
                pubInputBridgeTipStateHash,
                chainLedgerHashes[BRIDGE_TRANSITION_FRONTIER_LEN - 1]
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
                for {
                    let i := 0
                } lt(i, BRIDGE_TRANSITION_FRONTIER_LEN) {
                    i := add(i, 1)
                } {
                    let state_ptr := add(pubInput, 0x40)
                    let ledger_ptr := add(
                        pubInput,
                        add(0x40, mul(0x20, BRIDGE_TRANSITION_FRONTIER_LEN))
                    )

                    sstore(add(chainStateHashes.slot, i), mload(state_ptr))
                    state_ptr := add(state_ptr, 0x20)
                    sstore(add(chainLedgerHashes.slot, i), mload(ledger_ptr))
                    ledger_ptr := add(ledger_ptr, 0x20)
                }
            }
        } else {
            revert NewStateIsNotValid();
        }
    }

    function updateAccount(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes memory pubInput
    ) external {
        bytes32 ledgerHash;
        bytes32 accountHash;
        bytes32 accountIdHash;
        assembly {
            ledgerHash := mload(add(pubInput, 0x20))
            accountHash := mload(add(pubInput, 0x40))
            accountIdHash := mload(add(pubInput, 0x60))
        }

        bytes32 pubInputCommitment = keccak256(pubInput);

        bool isAccountVerified = aligned.verifyBatchInclusion(
            proofCommitment,
            pubInputCommitment,
            provingSystemAuxDataCommitment,
            proofGeneratorAddr,
            batchMerkleRoot,
            merkleProof,
            verificationDataBatchIndex
        );

        if (isAccountVerified) {
            accounts[accountIdHash] = Account.LedgerAccountPair(
                ledgerHash,
                accountHash
            );
        } else {
            revert AccountIsNotValid(accountIdHash);
        }
    }
}
