// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./BN254.sol";

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

    function pow(FE self, uint256 exponent) internal pure returns (FE result) {
        result = FE.wrap(1);
        while (exponent != 0) {
            if (exponent & 1 == 1) {
                result = mul(result, self);
            }
            self = mul(self, self);
            exponent = exponent >> 1;
        }
    }
}

/// @notice Implements 256 bit modular arithmetic over the scalar field of bn254.

library Scalar {
    type FE is uint256;

    using {add, mul, inv, neg, sub} for FE;

    uint256 internal constant MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 internal constant TWO_ADIC_PRIMITIVE_ROOT_OF_UNITY =
        19103219067921713944291392827692070036145651957329286315305642004821462161904;
    uint256 internal constant TWO_ADICITY = 28;

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
        uint256 integer = 0;
        uint256 count = b.length <= 32 ? b.length : 32;

        for (uint256 i = 0; i < count; i++) {
            integer <<= 8;
            integer += uint8(b[i]);
        }
        return FE.wrap(integer % MODULUS);
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

    function double(FE self) internal pure returns (FE res) {
        res = mul(self, FE.wrap(2));
    }

    function square(FE self) internal pure returns (FE res) {
        res = mul(self, self);
    }

    function inv(FE self) internal view returns (FE inverse) {
        inverse = FE.wrap(BN254.invert(FE.unwrap(self)));
    }

    function neg(FE self) internal pure returns (FE) {
        return FE.wrap(MODULUS - FE.unwrap(self));
    }

    function sub(FE self, FE other) internal pure returns (FE res) {
        assembly ("memory-safe") {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }

    function pow(FE self, uint256 exponent) internal view returns (FE result) {
        uint256 base = FE.unwrap(self);
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
        result = FE.wrap(o);
    }

    error RootOfUnityError();
    /// @notice returns a primitive root of unity of order $2^{order}$.
    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/

    function get_primitive_root_of_unity(uint256 order) internal view returns (FE root) {
        if (order == 0) {
            return FE.wrap(1);
        }
        if (order > TWO_ADICITY) {
            revert RootOfUnityError();
        }

        uint256 log_power = TWO_ADICITY - order;
        root = from(TWO_ADIC_PRIMITIVE_ROOT_OF_UNITY);
        for (uint256 i = 0; i < log_power; i++) {
            root = square(root);
        }

        require(FE.unwrap(pow(root, 1 << order)) == 1, "not a root of unity");
    }
}

library Aux {
    /// @notice Extended euclidean algorithm. Returns [gcd, Bezout_a]
    /// @notice so gcd = a*Bezout_a + b*Bezout_b.
    /// @notice source: https://www.extendedeuclideanalgorithm.com/code
    function xgcd(uint256 a, uint256 b) internal pure returns (uint256 r0, uint256 s0) {
        r0 = a;
        uint256 r1 = b;
        s0 = 1;
        uint256 s1 = 0;
        uint256 t0 = 0;
        uint256 t1 = 1;

        uint256 n = 0;
        while (r1 != 0) {
            uint256 q = r0 / r1;
            r0 = r0 > q * r1 ? r0 - q * r1 : q * r1 - r0; // abs

            // swap r0, r1
            uint256 temp = r0;
            r0 = r1;
            r1 = temp;

            s0 = s0 + q * s1;

            // swap s0, s1
            temp = s0;
            s0 = s1;
            s1 = temp;

            t0 = t0 + q * t1;

            // swap t0, t1
            temp = t0;
            t0 = t1;
            t1 = temp;

            ++n;
        }

        if (n % 2 != 0) {
            s0 = b - s0;
        } else {
            t0 = a - t0;
        }
    }
}
