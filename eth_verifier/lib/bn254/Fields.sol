// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {BN254} from "./BN254.sol";

/// @notice Implements 256 bit modular arithmetic over the scalar field of bn254.
library Scalar {
    using {add, mul, inv, neg, sub} for uint256;

    uint256 internal constant MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 internal constant TWO_ADIC_PRIMITIVE_ROOT_OF_UNITY =
        19103219067921713944291392827692070036145651957329286315305642004821462161904;
    uint256 internal constant TWO_ADICITY = 28;

    function zero() internal pure returns (uint256) {
        return 0;
    }

    function one() internal pure returns (uint256) {
        return 1;
    }

    function from(uint256 n) internal pure returns (uint256) {
        return n % MODULUS;
    }

    function from_bytes_be(bytes memory b) internal pure returns (uint256) {
        uint256 integer = 0;
        uint256 count = b.length <= 32 ? b.length : 32;

        for (uint256 i = 0; i < count; i++) {
            integer <<= 8;
            integer += uint8(b[i]);
        }
        return integer % MODULUS;
    }

    function add(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function double(uint256 self) internal pure returns (uint256 res) {
        res = mul(self, 2);
    }

    function square(uint256 self) internal pure returns (uint256 res) {
        res = mul(self, self);
    }

    function inv(uint256 self) internal view returns (uint256 inverse) {
        inverse = BN254.invert(self);
    }

    function neg(uint256 self) internal pure returns (uint256) {
        return MODULUS - self;
    }

    function sub(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }

    function pow(uint256 self, uint256 exponent) internal view returns (uint256 result) {
        uint256 base = self;
        uint256 o;
        assembly ("memory-safe") {
            // define pointer
            let p := mload(0x40)
            // store data assembly ("memory-safe")-favouring ways
            mstore(p, 0x20) // Length of Base
            mstore(add(p, 0x20), 0x20) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), base) // Base
            mstore(add(p, 0x80), exponent) // Exponent
            mstore(add(p, 0xa0), MODULUS) // Modulus
            if iszero(staticcall(sub(gas(), 2000), 0x05, p, 0xc0, p, 0x20)) { revert(0, 0) }
            // data
            o := mload(p)
        }
        result = o;
    }
}

/// @notice Implements 256 bit modular arithmetic over the base field of bn254.
library Base {
    uint256 internal constant MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function zero() internal pure returns (uint256) {
        return 0;
    }

    function one() internal pure returns (uint256) {
        return 1;
    }

    function from(uint256 n) internal pure returns (uint256) {
        return n % MODULUS;
    }

    function from_bytes_be(bytes memory b) internal pure returns (uint256) {
        uint256 offset = b.length < 32 ? (32 - b.length) * 8 : 0;
        uint256 integer = uint256(bytes32(b)) >> offset;
        if (integer > MODULUS) {
            integer -= MODULUS;
        }

        return integer;
    }

    function add(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function square(uint256 self) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := mulmod(self, self, MODULUS) // mulmod has arbitrary precision
        }
    }

    function neg(uint256 self) internal pure returns (uint256) {
        return MODULUS - self;
    }

    function sub(uint256 self, uint256 other) internal pure returns (uint256 res) {
        assembly ("memory-safe") {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }
}
