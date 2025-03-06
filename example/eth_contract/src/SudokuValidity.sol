// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "mina_bridge/contract/src/MinaStateSettlementExample.sol";
import "mina_bridge/contract/src/MinaAccountValidationExample.sol";

contract SudokuValidity {
    error InvalidZkappAccount(); // f281a183
    error InvalidLedger(bytes32 ledgerHash); // 76f145ea
    error IncorrectZkappAccount(bytes32 verificationKeyHash); // 170e89eb
    error UnsolvedSudoku(); // a3790c0e

    /// @notice The Sudoku zkApp verification key hash.
    bytes32 constant ZKAPP_VERIFICATION_KEY_HASH =
        0xdc9c283f73ce17466a01b90d36141b848805a3db129b6b80d581adca52c9b6f3;

    /// @notice Mina bridge contract that validates and stores Mina states.
    MinaStateSettlementExample stateSettlement;
    /// @notice Mina bridge contract that validates accounts
    MinaAccountValidationExample accountValidation;

    /// @notice Latest timestamp (Unix time) at which the contract determined that a
    //  Sudoku was solved in the Mina ZkApp.
    uint256 latestSolutionValidationAt = 0;

    constructor(address _stateSettlementAddr, address _accountValidationAddr) {
        stateSettlement = MinaStateSettlementExample(_stateSettlementAddr);
        accountValidation = MinaAccountValidationExample(_accountValidationAddr);
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

        MinaAccountValidationExample.AlignedArgs memory args = MinaAccountValidationExample.AlignedArgs(
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
        MinaAccountValidationExample.Account memory account = abi.decode(encodedAccount, (MinaAccountValidationExample.Account));

        // check that this account represents the circuit we expect
        bytes32 verificationKeyHash = keccak256(
            abi.encode(account.zkapp.verificationKey)
        );
        if (verificationKeyHash != ZKAPP_VERIFICATION_KEY_HASH) {
            revert IncorrectZkappAccount(verificationKeyHash);
        }

        // if isSolved == true
        if (account.zkapp.appState[1] != 0) {
            latestSolutionValidationAt = block.timestamp;
        } else {
            revert UnsolvedSudoku();
        }
    }
}
