// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/// @notice Implements 256 bit modular arithmetic over the base field of BN254.G1.
library BaseField {
    uint256 public constant MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583; // FIXME: correct mod
    type FE is uint256;

    function add(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    /// @notice Extended euclidean algorithm. Returns [gcd, Bezout_a, Bezout_b]
    /// @notice so gcd = a*Bezout_a + b*Bezout_b.
    /// @notice source: https://www.extendedeuclideanalgorithm.com/code
    function xgcd(
        uint256 a,
        uint256 b,
        uint256 s1,
        uint256 s2,
        uint256 t1,
        uint256 t2
    ) private returns (uint256, uint256, uint256) {
        if (b == 0) {
            return (a, 1, 0);
        }

        uint256 q = a / b;
        uint256 r = a - q * b;
        uint256 s3 = s1 - q * s2;
        uint256 t3 = t1 - q * t2;

        if (r == 0) {
            return (b, s2, t2);
        } else {
            return xgcd(b, r, s2, s3, t2, t3);
        }
    }
}
