// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned-layer/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state converted into a Fp.
    uint256 public lastVerifiedStateHash;

    function getLastVerifiedStateHash() public view returns (uint256) {
        return lastVerifiedStateHash;
    }

    function updateLastVerifiedState() external {
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
    }
}
