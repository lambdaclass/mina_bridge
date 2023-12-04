// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/Fields.sol";
import "./UtilsExternal.sol";
import "forge-std/console.sol";

using { BN254.add, BN254.neg, BN254.scalarMul } for BN254.G1Point;
using { Scalar.pow, Scalar.inv, Scalar.add, Scalar.mul, Scalar.neg } for Scalar.FE;

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

    /// @notice implements iterative FFT via the Cooley-Tukey algorithm for BN254 scalar field.
    /// @notice needs a final bit reversing permutation of the output.
    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/
    function nr_2radix_fft(Scalar.FE[] memory scalars, Scalar.FE[] memory twiddles)
        public
        view
        returns (Scalar.FE[] memory results)
    {
        uint256 n = scalars.length;
        require(is_power_of_two(n), "fft with size non power of two");

        if (n == 1) {
            return scalars;
        }

        // divide input in groups, starting with 1, duplicating the number of groups in each stage.
        uint group_count = 1;
        uint group_size = scalars.length;

        // for each group, there'll be group_size / 2 butterflies.
        // a butterfly is the atomic operation of a FFT, e.g: (a, b) = (a + wb, a - wb).
        // The 0.5 factor is what gives FFT its performance, it recursively halves the problem size
        // (group size).

        results = scalars;

        while (group_count < scalars.length) {
            for (uint group = 0; group < group_count; group++) {
                uint first_in_group = group * group_size;
                uint first_in_next_group = first_in_group + group_size / 2;

                Scalar.FE w = twiddles[group]; // a twiddle factor is used per group

                for (uint i = first_in_group; i < first_in_next_group; i++) {
                    Scalar.FE wi = results[i + group_size / 2].mul(w);

                    Scalar.FE y0 = results[i].add(wi);
                    Scalar.FE y1 = results[i].add(wi.neg());

                    results[i] = y0;
                    results[i + group_size / 2] = y1;
                }
            }
            group_count *= 2;
            group_size /= 2;
        }
    }

    function get_twiddles(uint order) public view returns (Scalar.FE[] memory twiddles) {
        Scalar.FE root = Scalar.get_primitive_root_of_unity(order);

        uint size = 1 << (order - 1);
        twiddles = new Scalar.FE[](size);
        twiddles[0] = Scalar.from(1);
        for (uint i = 1; i < size; i++) {
            twiddles[i] = twiddles[i - 1].mul(root);
        }
    }

    function get_twiddles_inv(uint order) public view returns (Scalar.FE[] memory twiddles) {
        Scalar.FE root = Scalar.get_primitive_root_of_unity(order).inv();

        uint size = 1 << (order - 1);
        twiddles = new Scalar.FE[](size);
        twiddles[0] = Scalar.from(1);
        for (uint i = 1; i < size; i++) {
            twiddles[i] = twiddles[i - 1].mul(root);
        }
    }

    /// @notice permutes the elements in bit-reverse order.
    function bit_reverse_permut(Scalar.FE[] memory scalars) public view returns (Scalar.FE[] memory result){
        result = scalars;
        for (uint i = 0; i < scalars.length; i++) {
            uint bit_reverse_index = bit_reverse(i, scalars.length);
            if (bit_reverse_index > i) {
                Scalar.FE temp = result[i];
                result[i] = result[bit_reverse_index];
                result[bit_reverse_index] = temp;
            }
        }
    }

    /// @notice permutes the elements in bit-reverse order.
    function bit_reverse_permut(BN254.G1Point[] memory points) public view returns (BN254.G1Point[] memory result){
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
    function bit_reverse(uint i, uint size) public view returns (uint) {
        if (size == 1) return i;
        return UtilsExternal.reverseEndianness(i) >> (256 - max_log2(size));
    }

    /// @notice runs FFT for BN254.
    function fft(BN254.G1Point[] memory points) public view returns (BN254.G1Point[] memory results) {
        (uint size, uint order) = next_power_of_two(points.length);

        if (size > points.length) {
            // zero padding
            BN254.G1Point[] memory new_points = new BN254.G1Point[](size);
            for (uint i = 0; i < size; i++) {
                new_points[i] = i < points.length ? points[i] : BN254.point_at_inf();
            }
            points = new_points;
        }

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles(order));
        BN254.G1Point[] memory unordered_res = nr_2radix_fft(points, twiddles);
        return bit_reverse_permut(unordered_res);
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

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles_inv(order));
        BN254.G1Point[] memory unordered_res = nr_2radix_fft(points, twiddles);
        return bit_reverse_permut(unordered_res);
    }

    /// @notice runs FFT for BN254 scalar field.
    function fft(Scalar.FE[] memory scalars) public view returns (Scalar.FE[] memory results) {
        (uint size, uint order) = next_power_of_two(scalars.length);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint i = 0; i < size; i++) {
                new_scalars[i] = i < scalars.length ? scalars[i] : Scalar.zero();
            }
            scalars = new_scalars;
        }

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles(order));
        Scalar.FE[] memory unordered_res = nr_2radix_fft(scalars, twiddles);
        return bit_reverse_permut(unordered_res);
    }

    /// @notice runs FFT for BN254 scalar field, padding with zeros to retrieve `count` elements.
    /// @notice or the next power of two from that.
    /// @notice `count` needs to be greater or equal than `scalars` length.
    function fft_resized(Scalar.FE[] memory scalars, uint count) public view returns (Scalar.FE[] memory results) {
        require(count >= scalars.length, "tried to execute resized fft with size smaller than input length");
        (uint size, uint order) = next_power_of_two(count);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint i = 0; i < size; i++) {
                new_scalars[i] = i < scalars.length ? scalars[i] : Scalar.zero();
            }
            scalars = new_scalars;
        }

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles(order));
        Scalar.FE[] memory unordered_res = nr_2radix_fft(scalars, twiddles);
        return bit_reverse_permut(unordered_res);
    }

    /// @notice runs inverse FFT for BN254 scalar field.
    function ifft(Scalar.FE[] memory scalars) public view returns (Scalar.FE[] memory results) {
        (uint size, uint order) = next_power_of_two(scalars.length);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint i = 0; i < size; i++) {
                new_scalars[i] = i < scalars.length ? scalars[i] : Scalar.zero();
            }
            scalars = new_scalars;
        }

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles_inv(order));
        Scalar.FE[] memory unordered_res = nr_2radix_fft(scalars, twiddles);
        return bit_reverse_permut(unordered_res);
    }

    /// @notice returns true if n is a power of two.
    function is_power_of_two(uint256 n) public pure returns (bool) {
        do {
            if (n == 2) return true;
            n /= 2;
        } while (n % 2 == 0);

        return false;
    }

    /// @notice returns the next power of two of n, or n if it's already a pow of two,
    // and the order.
    function next_power_of_two(uint256 n) public pure returns (uint res, uint order) {
        res = n - 1;
        for (uint i = 1; i < 256; i *= 2) {
            res |= res >> i;
        }
        res = res + 1;
        order = trailing_zeros(res);
    }

    /// @notice returns the trailing zeros of n.
    function trailing_zeros(uint256 n) public pure returns (uint i) {
        i = 0;
        while (n & 1 == 0) {
            n >>= 1;
            i++;
        }
    }

    /// @notice returns the log2 of the next power of two of n.
    function max_log2(uint256 n) public pure returns (uint log) {
        (uint _res, uint log) = next_power_of_two(n);
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

    /// @notice returns maximum between a and b.
    function max(uint a, uint b) public pure returns (uint) {
       return a < b ? b : a;
    }

    /// @notice converts an ASCII string into a uint.
    error InvalidStringToUint();
    function str_to_uint(string memory s) public pure returns (uint res) {
        bytes memory b = bytes(s);
        res = 0;
        for (uint i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                res *= 10;
                res += uint8(b[i]) - 0x30;
            } else {
                revert InvalidStringToUint();
            }
        }
    }
}
