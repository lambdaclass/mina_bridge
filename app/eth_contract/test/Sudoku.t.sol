// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {Sudoku} from "../src/Sudoku.sol";

contract SudokuTest is Test {
    Sudoku public sudoku;

    function setUp() public {
        sudoku = new Sudoku();
    }
}
