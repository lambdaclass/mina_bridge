// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Sudoku} from "../src/Sudoku.sol";

contract SudokuScript is Script {
    Sudoku public sudoku;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        sudoku = new Sudoku();

        vm.stopBroadcast();
    }
}
