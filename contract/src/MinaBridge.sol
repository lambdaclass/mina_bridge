// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";
import "./Account.sol";

error NewStateIsNotValid();
error TipStateIsWrong(bytes32 pubInputTipStateHash, bytes32 tipStatehash);
error AccountIsNotValid(bytes32 accountIdHash);

/// @title Mina to Ethereum Bridge's smart contract.
contract MinaBridge {
    /// @notice The state hash of the last verified state as a Fp.
    bytes32 tipStateHash;
    /// @notice The ledger hash of the last verified state as a Fp.
    bytes32 tipLedgerHash;

    /// @notice mapping of a keccak256(TokenId) => verified account hash and its ledger hash.
    mapping(bytes32 => Account.LedgerAccountPair) accounts;

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address _alignedServiceAddr, bytes32 _tipStateHash) {
        aligned = AlignedLayerServiceManager(_alignedServiceAddr);
        tipStateHash = _tipStateHash;
    }

    /// @notice Returns the last verified state hash.
    function getTipStateHash() external view returns (bytes32) {
        return tipStateHash;
    }

    /// @notice Returns the last verified ledger hash.
    function getTipLedgerHash() external view returns (bytes32) {
        return tipLedgerHash;
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
        return accounts[accountIdHash].ledgerHash == tipLedgerHash;
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
            pubInputTipStateHash := mload(add(pubInput, 0x60))
        }

        if (pubInputTipStateHash != tipStateHash) {
            revert TipStateIsWrong(pubInputTipStateHash, tipStateHash);
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
            // first 32 bytes of pub input is the candidate (now verified) ledger hash.
            // second 32 bytes of pub input is the candidate (now verified) state hash.
            assembly {
                sstore(tipLedgerHash.slot, mload(add(pubInput, 0x20)))
                sstore(tipStateHash.slot, mload(add(pubInput, 0x40)))
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
