// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./BN254.sol";
import "./Fields.sol";

using { BN254.add, BN254.neg, BN254.scalarMul } for BN254.G1Point;
using { Base.pow } for Base.FE;

library Utils {
    /// @notice implements FFT via the recursive Cooley-Tukey algorithm for BN254.
    function cooley_tukey(BN254.G1Point[] memory points, Scalar.FE root)
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
            BN254.G1Point memory b = transf_odd[k].scalarMul(Scalar.FE.unwrap(Scalar.pow(root, k)));

            results[k] = a.add(b);
            results[k + n / 2] = a.add(b.neg());
        }
    }

    /// @notice runs inverse FFT for BN254.
    function ifft(BN254.G1Point[] memory points) public view returns (BN254.G1Point[] memory results) {
        (uint size, uint order) = next_power_of_two(points.length);
        Scalar.FE root = Scalar.get_primitive_root_of_unity(order);

        if (size > points.length) {
            // zero padding
            BN254.G1Point[] memory new_points = new BN254.G1Point[](size);
            for (uint i = 0; i < size; i++) {
                new_points[i] = i < points.length ? points[i] : BN254.point_at_inf();
            }
            points = new_points;
        }

        return cooley_tukey(points, Scalar.inv(root));
    }

    /// @notice returns true if n is a power of two.
    function is_power_of_two(uint256 n) public pure returns (bool) {
        do {
            if (n == 1) return true;
            n /= 2;
        } while (n % 2 == 0);

        return false;
    }

    /// @notice returns the binary logarithm of n.
    function log2(uint256 n) public pure returns (uint256 res) {
        res = n - 1;
        for (uint i = 1; i < 256; i *= 2) {
            res |= res >> i;
        }
    }

    /// @notice returns the next power of two of n, or n if it's already a pow of two,
    // and the order.
    function next_power_of_two(uint256 n) public pure returns (uint256 res, uint256 pow) {
        if (is_power_of_two(n)) {
            return (n, log2(n));
        }
        pow = log2(n) + 1;
        res = 1 << pow;

        require(is_power_of_two(res));
        require(res > n);
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

    /// @notice returns minimum between a and b.
    function min(uint a, uint b) public pure returns (uint) {
       return a < b ? a : b;
    }
}
