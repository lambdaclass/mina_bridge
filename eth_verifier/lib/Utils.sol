// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/Fields.sol";
import "./UtilsExternal.sol";
import "forge-std/console.sol";

using {BN254.add, BN254.neg, BN254.scalarMul} for BN254.G1Point;
using {Scalar.pow, Scalar.inv, Scalar.add, Scalar.mul, Scalar.neg} for Scalar.FE;

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
        uint256 group_count = 1;
        uint256 group_size = points.length;

        // for each group, there'll be group_size / 2 butterflies.
        // a butterfly is the atomic operation of a FFT, e.g: (a, b) = (a + wb, a - wb).
        // The 0.5 factor is what gives FFT its performance, it recursively halves the problem size
        // (group size).

        results = points;

        while (group_count < points.length) {
            for (uint256 group = 0; group < group_count; group++) {
                uint256 first_in_group = group * group_size;
                uint256 first_in_next_group = first_in_group + group_size / 2;

                uint256 w = Scalar.FE.unwrap(twiddles[group]); // a twiddle factor is used per group

                for (uint256 i = first_in_group; i < first_in_next_group; i++) {
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
        pure
        returns (Scalar.FE[] memory results)
    {
        uint256 n = scalars.length;
        require(is_power_of_two(n), "fft with size non power of two");

        if (n == 1) {
            return scalars;
        }

        // divide input in groups, starting with 1, duplicating the number of groups in each stage.
        uint256 group_count = 1;
        uint256 group_size = scalars.length;

        // for each group, there'll be group_size / 2 butterflies.
        // a butterfly is the atomic operation of a FFT, e.g: (a, b) = (a + wb, a - wb).
        // The 0.5 factor is what gives FFT its performance, it recursively halves the problem size
        // (group size).

        results = scalars;

        while (group_count < scalars.length) {
            for (uint256 group = 0; group < group_count; group++) {
                uint256 first_in_group = group * group_size;
                uint256 first_in_next_group = first_in_group + group_size / 2;

                Scalar.FE w = twiddles[group]; // a twiddle factor is used per group

                for (uint256 i = first_in_group; i < first_in_next_group; i++) {
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

    function get_twiddles(uint256 order) public pure returns (Scalar.FE[] memory twiddles) {
        Scalar.FE root = Scalar.get_primitive_root_of_unity(order);

        uint256 size = 1 << (order - 1);
        twiddles = new Scalar.FE[](size);
        twiddles[0] = Scalar.from(1);
        for (uint256 i = 1; i < size; i++) {
            twiddles[i] = twiddles[i - 1].mul(root);
        }
    }

    function get_twiddles_inv(uint256 order) public view returns (Scalar.FE[] memory twiddles) {
        Scalar.FE root = Scalar.get_primitive_root_of_unity(order).inv();

        uint256 size = 1 << (order - 1);
        twiddles = new Scalar.FE[](size);
        twiddles[0] = Scalar.from(1);
        for (uint256 i = 1; i < size; i++) {
            twiddles[i] = twiddles[i - 1].mul(root);
        }
    }

    /// @notice permutes the elements in bit-reverse order.
    function bit_reverse_permut(Scalar.FE[] memory scalars) public pure returns (Scalar.FE[] memory result) {
        result = scalars;
        for (uint256 i = 0; i < scalars.length; i++) {
            uint256 bit_reverse_index = bit_reverse(i, scalars.length);
            if (bit_reverse_index > i) {
                Scalar.FE temp = result[i];
                result[i] = result[bit_reverse_index];
                result[bit_reverse_index] = temp;
            }
        }
    }

    /// @notice permutes the elements in bit-reverse order.
    function bit_reverse_permut(BN254.G1Point[] memory points) public pure returns (BN254.G1Point[] memory result) {
        result = points;
        for (uint256 i = 0; i < points.length; i++) {
            uint256 bit_reverse_index = bit_reverse(i, points.length);
            if (bit_reverse_index > i) {
                BN254.G1Point memory temp = result[i];
                result[i] = result[bit_reverse_index];
                result[bit_reverse_index] = temp;
            }
        }
    }

    /// @notice reverses the `log2(size)` first bits of `i`
    function bit_reverse(uint256 i, uint256 size) public pure returns (uint256) {
        if (size == 1) return i;
        return UtilsExternal.reverseEndianness(i) >> (256 - max_log2(size));
    }

    /// @notice runs FFT for BN254.
    function fft(BN254.G1Point[] memory points) public view returns (BN254.G1Point[] memory results) {
        (uint256 size, uint256 order) = next_power_of_two(points.length);

        if (size > points.length) {
            // zero padding
            BN254.G1Point[] memory new_points = new BN254.G1Point[](size);
            for (uint256 i = 0; i < size; i++) {
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
        (uint256 size, uint256 order) = next_power_of_two(points.length);

        if (size > points.length) {
            // zero padding
            BN254.G1Point[] memory new_points = new BN254.G1Point[](size);
            for (uint256 i = 0; i < size; i++) {
                new_points[i] = i < points.length ? points[i] : BN254.point_at_inf();
            }
            points = new_points;
        }

        Scalar.FE[] memory twiddles = bit_reverse_permut(get_twiddles_inv(order));
        BN254.G1Point[] memory unordered_res = nr_2radix_fft(points, twiddles);
        return bit_reverse_permut(unordered_res);
    }

    /// @notice runs FFT for BN254 scalar field.
    function fft(Scalar.FE[] memory scalars) public pure returns (Scalar.FE[] memory results) {
        (uint256 size, uint256 order) = next_power_of_two(scalars.length);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint256 i = 0; i < size; i++) {
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
    function fft_resized(Scalar.FE[] memory scalars, uint256 count) public pure returns (Scalar.FE[] memory results) {
        require(count >= scalars.length, "tried to execute resized fft with size smaller than input length");
        (uint256 size, uint256 order) = next_power_of_two(count);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint256 i = 0; i < size; i++) {
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
        (uint256 size, uint256 order) = next_power_of_two(scalars.length);

        if (size > scalars.length) {
            // zero padding
            Scalar.FE[] memory new_scalars = new Scalar.FE[](size);
            for (uint256 i = 0; i < size; i++) {
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
    function next_power_of_two(uint256 n) public pure returns (uint256 res, uint256 order) {
        res = n - 1;
        for (uint256 i = 1; i < 256; i *= 2) {
            res |= res >> i;
        }
        res = res + 1;
        order = trailing_zeros(res);
    }

    /// @notice returns the trailing zeros of n.
    function trailing_zeros(uint256 n) public pure returns (uint256 i) {
        i = 0;
        while (n & 1 == 0) {
            n >>= 1;
            i++;
        }
    }

    /// @notice returns the log2 of the next power of two of n.
    function max_log2(uint256 n) public pure returns (uint256 log) {
        (, log) = next_power_of_two(n);
    }

    /// @notice returns the odd and even terms of the `points` array.
    function get_odd_even(BN254.G1Point[] memory points)
        public
        pure
        returns (BN254.G1Point[] memory odd, BN254.G1Point[] memory even)
    {
        uint256 n = points.length;
        require(n % 2 == 0, "can\'t get odd and even from a non even sized array");

        odd = new BN254.G1Point[](n / 2);
        even = new BN254.G1Point[](n / 2);

        for (uint256 i = 0; i < n / 2; i++) {
            odd[i] = points[2 * i - 1];
            even[i] = points[2 * i];
        }
    }

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
