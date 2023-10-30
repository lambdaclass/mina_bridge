// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./BN254.sol";
import "./Fields.sol";
import "./UtilsExternal.sol";
import "forge-std/console.sol";

using { BN254.add, BN254.neg, BN254.scalarMul } for BN254.G1Point;
using { Scalar.pow, Scalar.inv } for Scalar.FE;

library Utils {
    /// @notice implements iterative FFT via the Cooley-Tukey algorithm for BN254.
    /// @notice needs a final bit reversing permutation of the output.
    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/
    function nr_2radix_fft(BN254.G1Point[] memory points, Scalar.FE[] memory twiddles)
        public
        view
        returns (BN254.G1Point[] memory results)
    {
        uint256 n = points.length;
        require(is_power_of_two(n), "fft with size non power of two");

        if (n == 1) {
            return points;
        }

        // divide input in groups, starting with 1, duplicating the number of groups in each stage.
        uint group_count = 1;
        uint group_size = points.length;

        // for each group, there'll be group_size / 2 butterflies.
        // a butterfly is the atomic operation of a FFT, e.g: (a, b) = (a + wb, a - wb).
        // The 0.5 factor is what gives FFT its performance, it recursively halves the problem size
        // (group size).

        results = points;

        while (group_count < points.length) {
            for (uint group = 0; group < group_count; group++) {
                uint first_in_group = group * group_size;
                uint first_in_next_group = first_in_group + group_size / 2;

                uint w = Scalar.FE.unwrap(twiddles[group]); // a twiddle factor is used per group

                for (uint i = first_in_group; i < first_in_next_group; i++) {
                    BN254.G1Point memory wi = results[i + group_size / 2].scalarMul(w);

                    BN254.G1Point memory y0 = results[i].add(wi);
                    BN254.G1Point memory y1 = results[i].add(wi.neg());

                    results[i] = y0;
                    results[i + group_size / 2] = y1;
                }
            }
            group_count *= 2;
            group_size /= 2;
        }
    }

    function get_twiddles(uint order) public view returns (Scalar.FE[] memory twiddles) {
        Scalar.FE root_inv = Scalar.get_primitive_root_of_unity(order).inv();

        for (uint i = 0; i < 1 << (order - 1); i++) {
            twiddles[i] = root_inv.pow(i);
        }
    }

    /// @notice permutes the elements in bit-reverse order.
    function bit_reverse_permut(BN254.G1Point[] memory points) public pure returns (BN254.G1Point[] memory result){
        result = points;
        for (uint i = 0; i < points.length; i++) {
            uint bit_reverse_index = bit_reverse(i, points.length);
            if (bit_reverse_index > i) {
                BN254.G1Point memory temp = result[i];
                result[i] = result[bit_reverse_index];
                result[bit_reverse_index] = temp;
            }
        }
    }

    /// @notice reverses the `log2(size)` first bits of `i`
    function bit_reverse(uint i, uint size) public pure returns (uint) {
        if (size == 1) return i;
        return UtilsExternal.reverseEndianness(i) >> (256 - log2(size));
    }

    /// @notice runs inverse FFT for BN254.
    function ifft(BN254.G1Point[] memory points) public view returns (BN254.G1Point[] memory results) {
        (uint size, uint order) = next_power_of_two(points.length);

        if (size > points.length) {
            // zero padding
            BN254.G1Point[] memory new_points = new BN254.G1Point[](size);
            for (uint i = 0; i < size; i++) {
                new_points[i] = i < points.length ? points[i] : BN254.point_at_inf();
            }
            points = new_points;
        }

        BN254.G1Point[] memory unordered_res = nr_2radix_fft(points, get_twiddles(order));
        return bit_reverse_permut(unordered_res);
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

    /// @notice Extended euclidean algorithm. Returns [gcd, Bezout_a]
    /// @notice so gcd = a*Bezout_a + b*Bezout_b.
    /// @notice source: https://www.extendedeuclideanalgorithm.com/code
    function xgcd(
        uint a,
        uint b
    ) public pure returns (uint s1, uint t1) {
        uint r1 = a;
        uint r2 = b;
        s1 = 1;
        t1 = 0;
        uint s2 = 0;
        uint t2 = 1;

        uint n = 0;
        while (r2 > 0) {
            uint q = r1 / r2;
            r1 = r1 > q*r2 ? r1 - q*r2 : q*r2 - r1; // abs
            s1 = s1 + q*s2;

            // swap s1, s2
            uint temp = s1;
            s1 = s2;
            s2 = temp;

            t1 = t1 + q*t2;

            // swap t1, t2
            temp = t1;
            t1 = t2;
            t2 = temp;

            n += 1;
        }

        if (n % 2 > 0) {
            s1 = b - s1;
        } else {
            t1 = a - t1;
        }
    }
}
