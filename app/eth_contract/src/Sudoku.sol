// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "mina_bridge/contract/src/MinaBridge.sol";
import "mina_bridge/contract/src/MinaAccountValidation.sol";

contract Sudoku {
    /// @notice The Sudoku zkApp verification key hash.
    uint256 public constant ZKAPP_VERIFICATION_KEY_HASH =
        19387792026269240922986233885372582803610254872042773421723960761233199555267;

    /// @notice Mina bridge contract that validates and stores Mina states.
    MinaBridge stateSettlement;

    /// @notice Mina bridge contract that validates accounts
    MinaAccountValidation accountValidation;

    uint64 latestSolutionValidationAt = 0;

    /// @notice Validates a Sudoku solution by bridging from Mina, and stores
    /// the last Unix time it was solved at.
    function validateSolution() external {
        // 1. take the zkApp account of Sudoku.
        // 2. take a relatively finalized state's ledger hash from
        //    the stateSettlement contract.
        // 3. verify the account for ledger hash (this involves calling the bridge core)
        // 4. if the account is valid, extract the zkApp state it
        // 5. if the isSolved bool is true, latestSolutionValidationAt = block.timestamp
    }
}
