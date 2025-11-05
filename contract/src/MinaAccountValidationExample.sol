// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "aligned_layer/contracts/src/core/AlignedLayerServiceManager.sol";

error MinaAccountProvingSystemIdIsNotValid(bytes32); // c1872967

/// WARNING: This contract is meant ot be used as an example of how to use the Bridge.
/// NEVER use this contract in a production environment.
contract MinaAccountValidationExample {
    /// @notice The commitment to Mina Account proving system ID.
    bytes32 constant PROVING_SYSTEM_ID_COMM = 0xee2a4bc7db81da2b7164e56b3649b1e2a09c58c455b15dabddd9146c7582cebc;

    struct AlignedArgs {
        bytes32 proofCommitment;
        bytes32 provingSystemAuxDataCommitment;
        bytes20 proofGeneratorAddr;
        bytes32 batchMerkleRoot;
        bytes merkleProof;
        uint256 verificationDataBatchIndex;
        bytes pubInput;
        address batcherPaymentService;
    }

    /// @notice Reference to the AlignedLayerServiceManager contract.
    AlignedLayerServiceManager aligned;

    constructor(address payable _alignedServiceAddr) {
        aligned = AlignedLayerServiceManager(_alignedServiceAddr);
    }

    function validateAccount(AlignedArgs calldata args) external view returns (bool) {
        if (args.provingSystemAuxDataCommitment != PROVING_SYSTEM_ID_COMM) {
            revert MinaAccountProvingSystemIdIsNotValid(args.provingSystemAuxDataCommitment);
        }

        bytes32 pubInputCommitment = keccak256(args.pubInput);

        return aligned.verifyBatchInclusion(
            args.proofCommitment,
            pubInputCommitment,
            args.provingSystemAuxDataCommitment,
            args.proofGeneratorAddr,
            args.batchMerkleRoot,
            args.merkleProof,
            args.verificationDataBatchIndex,
            args.batcherPaymentService
        );
    }

    function validateAccountAndReturn(AlignedArgs calldata args) external view returns (Account memory) {
        if (args.provingSystemAuxDataCommitment != PROVING_SYSTEM_ID_COMM) {
            revert MinaAccountProvingSystemIdIsNotValid(args.provingSystemAuxDataCommitment);
        }

        bytes32 pubInputCommitment = keccak256(args.pubInput);

        bool isAccountVerified = aligned.verifyBatchInclusion(
            args.proofCommitment,
            pubInputCommitment,
            args.provingSystemAuxDataCommitment,
            args.proofGeneratorAddr,
            args.batchMerkleRoot,
            args.merkleProof,
            args.verificationDataBatchIndex,
            args.batcherPaymentService
        );

        if (isAccountVerified) {
            return abi.decode(args.pubInput[32 + 8:], (Account));
        } else {
            revert();
        }
    }

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
}
