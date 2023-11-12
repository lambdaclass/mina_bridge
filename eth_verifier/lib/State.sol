// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

struct State {
    /// Public key of account that produced this block encoded in base58.
    string creator;
    /// Hash of the state after this block.
    uint256 hash;
    /// Block height at which balance was measured.
    uint256 block_height;
}
