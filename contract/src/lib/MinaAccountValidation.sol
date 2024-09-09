// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract MinaAccountValidation {
    struct Account {
        CompressedECPoint publicKey;
        bytes32 tokenIdKeyHash;
        string tokenSymbol;
        uint64 balance;
        uint32 nonce;
        bytes32 receiptChainHash;
        CompressedECPoint delegate;
        bytes32 votingFor;
        Timing timing;
        Permissions permissions;
        ZkappAccount zkapp;
    }

    /// @notice A compressed elliptic curve.
    struct CompressedECPoint {
        bytes32 x;
        bool isOdd;
    }

    struct Timing {
        uint64 initialMinimumBalance;
        uint32 cliffTime;
        uint64 cliffAmount;
        uint32 vestingPeriod;
        uint64 vestingIncrement;
    }

    enum AuthRequired {
        None,
        Either,
        Proof,
        Signature,
        Impossible
    }

    struct Permissions {
        AuthRequired editState;
        AuthRequired access;
        AuthRequired send;
        AuthRequired rreceive;
        AuthRequired setDelegate;
        AuthRequired setPermissions;
        AuthRequired setVerificationKeyAuth;
        uint32 setVerificationKeyUint;
        AuthRequired setZkappUri;
        AuthRequired editActionState;
        AuthRequired setTokenSymbol;
        AuthRequired incrementNonce;
        AuthRequired setVotingFor;
        AuthRequired setTiming;
    }

    struct ZkappAccount {
        bytes32[8] appState;
        VerificationKey verificationKey;
        uint32 zkappVersion;
        bytes32[5] actionState;
        uint32 lastActionSlot;
        bool provedState;
        bytes zkappUri;
    }

    struct VerificationKey {
        ProofsVerified maxProofsVerified;
        ProofsVerified actualWrapDomainSize;
        WrapIndex wrapIndex;
    }

    enum ProofsVerified {
        N0,
        N1,
        N2
    }

    struct WrapIndex {
        Commitment[7] sigmaComm;
        Commitment[15] coefficientsComm;
        Commitment genericComm;
        Commitment psmComm;
        Commitment completeAddComm;
        Commitment mulComm;
        Commitment emulComm;
        Commitment endomulScalarComm;
    }

    struct Commitment {
        bytes32 x;
        bytes32 y;
    }

    function validateAccount(Account calldata account) public returns (bool) {
        return false;
    }
}
