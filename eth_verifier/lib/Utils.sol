// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/Fields.sol";
import "./UtilsExternal.sol";
import "forge-std/console.sol";

using {BN254.add, BN254.neg, BN254.scalarMul} for BN254.G1Point;
using {Scalar.pow, Scalar.inv, Scalar.add, Scalar.mul, Scalar.neg} for Scalar.FE;

library Utils {
    /// @notice returns minimum between a and b.
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice returns maximum between a and b.
    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? b : a;
    }

    /// @notice converts an ASCII string into a uint.
    error InvalidStringToUint();

    function str_to_uint(string memory s) public pure returns (uint256 res) {
        bytes memory b = bytes(s);
        res = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                res *= 10;
                res += uint8(b[i]) - 0x30;
            } else {
                revert InvalidStringToUint();
            }
        }
    }

    /// @notice flattens an array of `bytes` (so 2D array of the `byte` type)
    /// @notice assumed to be padded so every element is 32 bytes long.
    //
    // @notice this function will both flat and remove the padding.
    function flatten_padded_be_bytes_array(bytes[] memory b) public pure returns (bytes memory) {
        uint256 byte_count = b.length;
        bytes memory flat_b = new bytes(byte_count);
        for (uint256 i = 0; i < byte_count; i++) {
            flat_b[i] = b[i][32 - 1];
        }
        return flat_b;
    }

    /// @notice flattens an array of `bytes` (so 2D array of the `byte` type)
    /// @notice assumed to be padded so every element is 32 bytes long.
    //
    // @notice this function will both flat and remove the padding.
    function flatten_padded_le_bytes_array(bytes[] memory b) public pure returns (bytes memory) {
        uint256 byte_count = b.length;
        bytes memory flat_b = new bytes(byte_count);
        for (uint256 i = 0; i < byte_count; i++) {
            flat_b[byte_count - i - 1] = b[i][32 - 1];
        }
        return flat_b;
    }

    /// @notice uses `flatten_padded_bytes_array()` to flat and remove the padding
    /// @notice of a `bytes[]` and reinterprets the result as a big-endian uint256.
    function padded_be_bytes_array_to_uint256(bytes[] memory b) public pure returns (uint256 integer) {
        bytes memory data_b = flatten_padded_be_bytes_array(b);
        require(data_b.length == 32, "not enough bytes in array");
        return uint256(bytes32(data_b));
    }

    /// @notice uses `flatten_padded_bytes_array()` to flat and remove the padding
    /// @notice of a `bytes[]` and reinterprets the result as a little-endian uint256.
    function padded_le_bytes_array_to_uint256(bytes[] memory b) public pure returns (uint256 integer) {
        bytes memory data_b = flatten_padded_le_bytes_array(b);
        require(data_b.length == 32, "not enough bytes in array");
        return uint256(bytes32(data_b));
    }

    /// @notice checks if two strings are equal
    function str_cmp(string memory self, string memory other) public pure returns (bool) {
        return keccak256(bytes(self)) == keccak256(bytes(other));
    }
}
