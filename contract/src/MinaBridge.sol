// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state converted into a Fp.
    uint256 public lastVerifiedStateHash;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address alignedServiceAddr) {
        aligned = AlignedLayerServiceManager(alignedServiceAddr);
    }

    function getLastVerifiedStateHash() public view returns (uint256) {
        return lastVerifiedStateHash;
    }

    function updateLastVerifiedState(
        bytes32 proofCommitment,
        bytes32 pubInputCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex
    ) external {
        /*
         * parameters:
         * - newStateVerificationData (excludes pubInputCommitment)
         * - newState
         * - newStateHash
         * - lastVerifiedState
         *
         * pseudocode:
         *    pubInputs = [newState, newStateHash, lastVerifiedState, lastVerifiedStateHash]
         *    pubInputsCommitment = keccak256(pubInputs)
         *
         *    bool isNewStateVerified = AlignedLayerServiceManager.verifyBatchInclusion(
         *        newStateVerificationData, pubInputCommitment
         *    );
         *
         *    if (isNewStateVerified) {
         *        lastVerifiedStateHash = newStateHash;
         *    } else {
         *        revert NewStateIsNotValid();
         *    }
         */

        // TOOD(xqft): add pub input hashing.
        uint256 newStateHash = 0x0;

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
            lastVerifiedStateHash = newStateHash;
        } else {
            revert NewStateIsNotValid();
        }
    }
}
