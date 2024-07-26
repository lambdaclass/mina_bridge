// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state converted into a Fp.
    uint256 lastVerifiedStateHash = 42;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address alignedServiceAddr) {
        aligned = AlignedLayerServiceManager(alignedServiceAddr);
    }

    function getLastVerifiedStateHash() external view returns (uint256) {
        return lastVerifiedStateHash;
    }

    function updateLastVerifiedState(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes memory pubInput
    ) external {
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
            // first 32 bytes of pub input is the candidate (now verified) state hash.
            assembly {
                sstore(lastVerifiedStateHash.slot, mload(add(pubInput, 0x20)))
            }
        } else {
            revert NewStateIsNotValid();
        }
    }
}
