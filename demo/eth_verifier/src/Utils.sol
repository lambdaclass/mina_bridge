// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./BN254.sol";
import "./Fields.sol";

using { BN254.add, BN254.neg, BN254.scalarMul } for BN254.G1Point;
using { Base.pow } for Base.FE;

library Utils {
    /// @notice implements FFT via the recursive Cooley-Tukey algorithm for BN254.
    function cooley_tukey(BN254.G1Point[] memory points, Base.FE root)
        public
        view
        returns (BN254.G1Point[] memory results)
    {
        uint256 n = points.length;
        require(is_power_of_two(n), "fft with size non power of two");

        if (n == 1) {
            return points;
        }

        (
            BN254.G1Point[] memory odd,
            BN254.G1Point[] memory even
        ) = get_odd_even(points);

        BN254.G1Point[] memory transf_odd = cooley_tukey(odd, root);
        BN254.G1Point[] memory transf_even = cooley_tukey(even, root);

        for (uint k = 0; k < n / 2; k++) {
            BN254.G1Point memory a = transf_even[k];
            BN254.G1Point memory b = transf_odd[k].scalarMul(Base.FE.unwrap(Base.pow(root, k)));

            results[k] = a.add(b);
            results[k + n / 2] = a.add(b.neg());
        }
    }

    /// @notice returns true if n is a power of two.
    function is_power_of_two(uint256 n) public pure returns (bool) {
        do {
            if (n == 1) return true;
            n /= 2;
        } while (n % 2 == 0);

        return false;
    }

    /// @notice returns the odd and even terms of the `points` array.
    function get_odd_even(BN254.G1Point[] memory points)
        public
        pure
        returns (BN254.G1Point[] memory odd, BN254.G1Point[] memory even)
    {
        uint256 n = points.length;
        require(
            n % 2 == 0,
            "can't get odd and even from a non even sized array"
        );

        odd = new BN254.G1Point[](n / 2);
        even = new BN254.G1Point[](n / 2);

        for (uint256 i = 0; i < n / 2; i++) {
            odd[i] = points[2 * i - 1];
            even[i] = points[2 * i];
        }
    }
}
