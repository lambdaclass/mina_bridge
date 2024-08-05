// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();
error TipStateIsWrong();

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state as a Fp.
    bytes32 tipStateHash = 0;

    /// @notice The state hash of the transition frontier's root.
    bytes32 rootStateHash;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address _alignedServiceAddr, bytes32 _rootStateHash) {
        aligned = AlignedLayerServiceManager(_alignedServiceAddr);
        rootStateHash = _rootStateHash;
    }

    /// @notice Returns the last verified state hash, or the root state hash if none.
    function getTipStateHash() external view returns (bytes32) {
        if (tipStateHash != 0) {
            return tipStateHash;
        } else {
            return rootStateHash;
        }
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
        bytes32 pubInputTipStateHash;
        assembly {
            mstore(pubInputTipStateHash, mload(add(pubInput, 0x40)))
        }

        if (pubInputTipStateHash != tipStateHash) {
            revert TipStateIsWrong();
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
            // first 32 bytes of pub input is the candidate (now verified) state hash.
            assembly {
                sstore(tipStateHash.slot, mload(add(pubInput, 0x20)))
            }
        } else {
            revert NewStateIsNotValid();
        }
    }
}
