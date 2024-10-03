// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "mina_bridge/contract/src/MinaStateSettlement.sol";
import "mina_bridge/contract/src/MinaAccountValidation.sol";

contract SudokuValidity {
    error InvalidZkappAccount();
    error InvalidLedger(bytes32 ledgerHash);
    error IncorrectZkappAccount(uint256 verificationKeyHash);
    error UnsolvedSudoku();

    /// @notice The Sudoku zkApp verification key hash.
    uint256 public constant ZKAPP_VERIFICATION_KEY_HASH =
        19387792026269240922986233885372582803610254872042773421723960761233199555267;

    /// @notice Mina bridge contract that validates and stores Mina states.
    MinaStateSettlement stateSettlement;
    /// @notice Mina bridge contract that validates accounts
    MinaAccountValidation accountValidation;

    /// @notice Latest timestamp (Unix time) at which the contract determined that a
    //  Sudoku was solved in the Mina ZkApp.
    uint256 latestSolutionValidationAt = 0;

    constructor(address _stateSettlementAddr, address _accountValidationAddr) {
        stateSettlement = MinaStateSettlement(_stateSettlementAddr);
        accountValidation = MinaAccountValidation(_accountValidationAddr);
    }

    function getLatestSolutionTimestamp() external view returns (uint256) {
        return latestSolutionValidationAt;
    }

    /// @notice Validates a Sudoku solution by bridging from Mina, and stores
    /// the last Unix time it was solved at.
    function validateSolution(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes calldata pubInput,
        address batcherPaymentService
    ) external {
        bytes32 ledgerHash = bytes32(pubInput[:32]);
        if (!stateSettlement.isLedgerVerified(ledgerHash)) {
            revert InvalidLedger(ledgerHash);
        }

        MinaAccountValidation.AlignedArgs memory args = MinaAccountValidation.AlignedArgs(
            proofCommitment,
            provingSystemAuxDataCommitment,
            proofGeneratorAddr,
            batchMerkleRoot,
            merkleProof,
            verificationDataBatchIndex,
            pubInput,
            batcherPaymentService
        );

        if (!accountValidation.validateAccount(args)) {
            revert InvalidZkappAccount();
        }

        bytes calldata encodedAccount = pubInput[32 + 8:];
        MinaAccountValidation.Account memory account = abi.decode(encodedAccount, (MinaAccountValidation.Account));

        // TODO(xqft): check verification key, it may be a poseidon hash so we should
        // need to change it to a keccak hash.
        // if (account.verificationKeyKash != ZKAPP_VERIFICATION_KEY_HASH) {
        //    revert IncorrectZkappAccount(account.verificationKeyHash);
        // }

        if (account.zkapp.appState[1] != 0) {
            latestSolutionValidationAt = block.timestamp;
        } else {
            revert UnsolvedSudoku();
        }
    }
}
