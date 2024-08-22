// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

library Account {
    /// @notice A compressed public key (ec. point) of a Mina account.
    struct CompressedPubKey {
        bytes32 x;
        bool isOdd;
    }

    /// @notice A Mina account is identified by its public key and token id.
    struct AccountId {
        CompressedPubKey publicKey;
        bytes32 tokenId;
    }

    /// @notice A verified account hash with its associated (also valid) ledger hash.
    struct LedgerAccountPair {
        bytes32 ledgerHash;
        bytes32 accountHash;
    }

    /// @notice Hashes an AccountId for storing as a key of a mapping.
    function hash_account_id(
        AccountId memory accountId
    ) private pure returns (bytes32) {
        assembly {
            mstore(0x00, keccak256(accountId, 0x41)) // bool is stored as single byte
            return(0x00, 0x20)
        }
    }
}
