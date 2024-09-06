// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

library MinaAccountValidation {
    struct Account {
        CompressedPubKey publicKey;
        bytes32 tokenIdKeyHash;
        string tokenSymbol;
        uint64 balance;
        uint32 nonce;
        bytes32 receiptChainHash;
        // delegate
        // votingFor
        // timing
        // permissions
        // zkapp
    }

    /// @notice A compressed public key (ec. point) of a Mina account.
    struct CompressedPubKey {
        bytes32 x;
        bool isOdd;
    }
}
