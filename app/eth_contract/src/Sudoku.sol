// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Sudoku {
    /// @notice The Sudoku zkApp verification key hash.
    uint256 public constant ZKAPP_VERIFICATION_KEY_HASH =
        19387792026269240922986233885372582803610254872042773421723960761233199555267;

    /// @notice Validates a Sudoku solution by bridging from Mina
    function validateSolution() external {}
}
