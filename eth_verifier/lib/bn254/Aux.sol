// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

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
