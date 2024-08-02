// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error NewStateIsNotValid();

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state as a Fp.
    bytes32 tipStateHash = 0;

    /// @notice The state hash of the genesis state as a Fp.
    uint256 constant genesisStateHash =
        23979920091195673795386525806121605315652663595695491169052082412294004666370;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address alignedServiceAddr) {
        aligned = AlignedLayerServiceManager(alignedServiceAddr);
    }

    /// @notice Returns the last verified state hash, or the genesis state hash if none.
    function getTipStateHash() external view returns (bytes32) {
        if (tipStateHash != 0) {
            return tipStateHash;
        } else {
            return bytes32(genesisStateHash);
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
