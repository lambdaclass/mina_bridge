// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Aux} from "./Aux.sol";

/// @notice Implements 256 bit modular arithmetic over the base field of bn254.
library Base {
    type FE is uint256;

    uint256 internal constant MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function zero() internal pure returns (FE) {
        return FE.wrap(0);
    }

    function one() internal pure returns (FE) {
        return FE.wrap(1);
    }

    function from(uint256 n) internal pure returns (FE) {
        return FE.wrap(n % MODULUS);
    }

    function from_bytes_be(bytes memory b) internal pure returns (FE) {
        uint256 offset = b.length < 32 ? (32 - b.length) * 8 : 0;
        uint256 integer = uint256(bytes32(b)) >> offset;
        if (integer > MODULUS) {
            integer -= MODULUS;
        }

        return FE.wrap(integer);
    }

    function add(FE self, FE other) internal pure returns (FE res) {
        assembly ("memory-safe") {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(FE self, FE other) internal pure returns (FE res) {
        assembly ("memory-safe") {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function square(FE self) internal pure returns (FE res) {
        assembly ("memory-safe") {
            res := mulmod(self, self, MODULUS) // mulmod has arbitrary precision
        }
    }

    function inv(FE self) internal pure returns (FE) {
        require(FE.unwrap(self) != 0, "tried to get inverse of 0");
        (uint256 gcd, uint256 inverse) = Aux.xgcd(FE.unwrap(self), MODULUS);
        require(gcd == 1, "gcd not 1");

        return FE.wrap(inverse);
    }

    function neg(FE self) internal pure returns (FE) {
        return FE.wrap(MODULUS - FE.unwrap(self));
    }

    function sub(FE self, FE other) internal pure returns (FE res) {
        assembly ("memory-safe") {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }
}
