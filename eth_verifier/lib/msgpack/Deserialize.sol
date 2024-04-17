// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Commitment.sol";
import "../bn254/BN254.sol";
import "../Evaluations.sol";
import "../Proof.sol";
import "../State.sol";
import "../Utils.sol";
import "../UtilsExternal.sol";
import "../VerifierIndex.sol";
import "forge-std/console.sol";

library MsgPk {
    using {Scalar.pow} for Scalar.FE;

    error EncodedMapKeyNotFound(bytes key);
    error StringMapKeyNotFound(string key);
    error NotImplementedType(bytes1 prefix);
    error UnmatchedTypePrefix(string type_name, bytes1 prefix);
    error UnmatchedGateType(string type_name);

    struct Stream {
        bytes data;
        uint256 curr_index;
    }

    struct EncodedArray {
        bytes[] values;
    }

    struct EncodedMap {
        bytes[] keys; // encoded strings or integers
        bytes[] values;
    }

    function new_stream(bytes memory data) public pure returns (Stream memory) {
        return Stream(data, 0);
    }

    /// @notice returns current byte and advances index.
    function next(Stream memory self) public pure returns (bytes1 b) {
        b = self.data[self.curr_index];
        self.curr_index += 1;
    }

    /// @notice returns current byte without advancing index.
    function curr(Stream memory self) public pure returns (bytes1) {
        return self.data[self.curr_index];
    }

    function next_n(Stream memory self, uint256 n) public pure returns (bytes memory consumed) {
        consumed = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            consumed[i] = self.data[self.curr_index + i];
        }
        self.curr_index += n;
    }

    /// @notice returns the bytes corresponding to the queried key
    function find_value(EncodedMap memory self, bytes memory key) public pure returns (bytes memory) {
        uint256 i = 0;
        while (i != self.keys.length && keccak256(self.keys[i]) != keccak256(key)) {
            i++;
        }
        if (i == self.keys.length) revert EncodedMapKeyNotFound(key);
        return self.values[i];
    }

    /// @notice returns the bytes corresponding to the queried string key
    function find_value_str(EncodedMap memory self, string memory string_key) public pure returns (bytes memory) {
        uint256 i = 0;
        bytes memory key = abi.encode(string_key);
        while (i != self.keys.length && keccak256(self.keys[i]) != keccak256(key)) {
            i++;
        }
        if (i == self.keys.length) revert StringMapKeyNotFound(string_key);
        return self.values[i];
    }

    /// @notice like find_value() but returns a boolean that indicates if
    /// @notice the key exists. If not found, the resulted bytes will be empty.
    function find_value_or_fail(EncodedMap memory self, bytes memory key) public pure returns (bytes memory, bool) {
        uint256 i = 0;
        while (i != self.keys.length && keccak256(self.keys[i]) != keccak256(key)) {
            i++;
        }
        if (i == self.keys.length) return (new bytes(0), false);
        return (self.values[i], true);
    }

    /// @notice deserializes the next type and returns the encoded data.
    function deser_encode(Stream memory self) public view returns (bytes memory) {
        bytes1 prefix = curr(self);
        if (prefix >> 5 == 0x05 || prefix == 0xd9 || prefix == 0xda || prefix == 0xdb) {
            return abi.encode(deser_str(self));
        } else if (prefix == 0xC4) {
            return abi.encode(deser_bin8(self));
        } else if (prefix >> 4 == 0x08) {
            return abi.encode(deser_fixmap(self));
        } else if (prefix >> 4 == 0x09) {
            return abi.encode(deser_fixarr(self));
        } else if (prefix == 0xde) {
            return abi.encode(deser_map16(self));
        } else if (prefix == 0xdc) {
            return abi.encode(deser_arr16(self));
        } else if (prefix >> 2 == 0x33) {
            return abi.encode(deser_uint(self));
        } else if (prefix >> 2 == 0x34) {
            return abi.encode(deser_int(self));
        } else if (prefix >> 7 == 0x00) {
            return abi.encode(deser_posfixint(self));
        } else if (prefix >> 5 == 0x07) {
            return abi.encode(deser_negfixint(self));
        } else if (prefix == 0xc2 || prefix == 0xc3) {
            return abi.encode(deser_bool(self));
        } else if (prefix == 0xc0) {
            return abi.encode(deser_null(self));
        } else {
            revert NotImplementedType(prefix);
        }
    }

    function deser_str(Stream memory self) public pure returns (string memory) {
        bytes1 first = next(self);
        require(first >> 5 == 0x05 || first == 0xd9 || first == 0xda || first == 0xdb, "not a fixstr or strX");

        if (first >> 5 == 0x05) {
            // fixstr
            uint256 n = uint256(uint8(first & 0x1F)); // low nibble + lsb of high nibble
            return string(next_n(self, n));
        } else {
            // strX

            // get length of string in bytes `n`
            uint256 n_byte_count = uint256(uint8(first & 0x03)); // least significant 2 bits
            bytes memory n_bytes = next_n(self, n_byte_count);
            uint256 n = 0;
            if (n_byte_count == 1) {
                n = uint8(bytes1(n_bytes));
            } else if (n_byte_count == 2) {
                n = uint16(bytes2(n_bytes));
            } else if (n_byte_count == 3) {
                n = uint32(bytes4(n_bytes));
            } else {
                revert("deser_str unexpected length");
            }

            return string(next_n(self, n));
        }
    }

    function deser_bin8(Stream memory self) public pure returns (bytes memory) {
        require(next(self) == 0xC4, "not a stream of bin8 (bytes)");

        // next byte is the length of the stream in one byte
        uint256 n = uint256(uint8(next(self)));

        // read data
        return next_n(self, n);
    }

    function deser_fixarr(Stream memory self) public view returns (EncodedArray memory arr) {
        bytes1 first = next(self);
        require(first >> 4 == 0x09, "not a fixarr");
        uint256 n = uint256(uint8(first & 0x0F)); // low nibble

        arr = EncodedArray(new bytes[](n));

        for (uint256 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_fixmap(Stream memory self) public view returns (EncodedMap memory map) {
        bytes1 first = next(self);
        require(first >> 4 == 0x08, "not a fixmap");
        uint256 n = uint256(uint8(first & 0x0F)); // low nibble

        map = EncodedMap(new bytes[](n), new bytes[](n));

        for (uint256 i = 0; i < n; i++) {
            map.keys[i] = deser_encode(self);
            map.values[i] = deser_encode(self);
        }
    }

    function deser_arr16(Stream memory self) public view returns (EncodedArray memory arr) {
        bytes1 first = next(self);
        require(first == 0xdc, "not an arr16");
        // size is next two bytes:

        uint16 n = uint16(bytes2(next_n(self, 2)));

        arr = EncodedArray(new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_arr32(Stream memory self) public view returns (EncodedArray memory arr) {
        bytes1 first = next(self);
        require(first == 0xdd, "not an arr32");
        // size is next two bytes:

        uint32 n = uint32(bytes4(next_n(self, 4)));

        arr = EncodedArray(new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_map16(Stream memory self) public view returns (EncodedMap memory map) {
        bytes1 first = next(self);
        require(first == 0xde, "not a map16");
        // size is next two bytes:

        uint16 n = uint16(bytes2(next_n(self, 2)));

        map = EncodedMap(new bytes[](n), new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            map.keys[i] = deser_encode(self);
            map.values[i] = deser_encode(self);
        }
    }

    function deser_uint(Stream memory self) public pure returns (uint256) {
        bytes1 first = next(self);
        if (first == 0) {
            return 0;
        }

        if (first >> 2 != 0x33) {
            revert UnmatchedTypePrefix("uint", first);
        }
        // 110011XX are uints of 8,16,32,64 bits.

        uint256 byte_count = 1 << uint8(first & 0x03); // mask with 11b
        bytes memory b = next_n(self, byte_count);
        if (byte_count == 1) {
            return uint8(bytes1(b));
        } else if (byte_count == 2) {
            return uint16(bytes2(b));
        } else if (byte_count == 3) {
            return uint32(bytes4(b));
        } else if (byte_count == 4) {
            return uint64(bytes8(b));
        }
    }

    function deser_int(Stream memory self) public pure returns (int256) {
        bytes1 first = next(self);
        require(first >> 2 == 0x34, "not a int");
        // 110100XX are ints of 8,16,32,64 bits.

        uint256 byte_count = 1 << uint8(first & 0x03); // mask with 11b
        bytes memory b = next_n(self, byte_count);

        // For decoding into a signed integer, we'll use solidity's ABI.
        // Referencing the spec, we need to pad to a 32 byte array with
        // 0xFF if the integer is negative, or with 0x00 if positive.
        // The sign can be determined checking the most significant bit.

        bytes1 pad_byte = b[0] & 0x40 == 0x40 ? bytes1(0xFF) : bytes1(0x00);
        bytes memory padded_b = new bytes(32);
        for (uint256 i = 0; i < 32 - b.length; i++) {
            padded_b[i] = pad_byte;
        }
        for (uint256 i = b.length; i < 32; i++) {
            padded_b[i] = b[i - b.length];
        }

        if (byte_count == 1) {
            return abi.decode(padded_b, (int8));
        } else if (byte_count == 2) {
            return abi.decode(padded_b, (int16));
        } else if (byte_count == 3) {
            return abi.decode(padded_b, (int32));
        } else if (byte_count == 4) {
            return abi.decode(padded_b, (int64));
        }
    }

    function deser_posfixint(Stream memory self) public pure returns (uint8) {
        bytes1 first = next(self);
        require(first >> 7 == 0x00, "not a positive fixint");

        return uint8(first);
    }

    function deser_negfixint(Stream memory self) public pure returns (int8) {
        bytes1 first = next(self);
        require(first >> 5 == 0x07, "not a negative fixint");

        // two's complement
        return int8(~(uint8(first) - 1)) * -1;
    }

    function deser_null(Stream memory self) public pure returns (string memory) {
        bytes1 first = next(self);
        require(first == 0xc0, "not null");

        return "null";
    }

    // @notice checks if `self` corresponds to the encoding of a `null` string.
    function is_null(bytes memory self) public pure returns (bool) {
        bytes memory null_encoded = abi.encode("null");
        if (self.length != null_encoded.length) return false;

        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] != null_encoded[i]) return false;
        }
        return true;
    }

    function deser_bool(Stream memory self) public pure returns (bool) {
        bytes1 first = next(self);
        require(first == 0xc2 || first == 0xc3, "not a bool");

        return first == 0xc3; // 0xc3 == true
    }

    // WARN: using the entire `full_urs` may not be necessary, we would only have to deserialize the
    // first two points (in the final verification step, we need the `full_urs` for commitment a
    // evaluation polynomial, which seems to be always of degree 1).
    function deser_pairing_urs(Stream memory self, URS storage urs) public {
        // full_srs and verifier_srs fields
        EncodedMap memory urs_map = deser_fixmap(self);

        EncodedMap memory full_urs_serialized = abi.decode(find_value_str(urs_map, "full_srs"), (EncodedMap));

        // get data from g and h fields (g is an array of bin8 and h is a bin8)
        EncodedArray memory full_urs_g_serialized = abi.decode(find_value_str(full_urs_serialized, "g"), (EncodedArray));
        bytes memory full_urs_h_serialized = abi.decode(find_value_str(full_urs_serialized, "h"), (bytes));

        // deserialized and save g for both URS
        // INFO: we only need the first two points
        BN254.G1Point[] memory full_urs_g = new BN254.G1Point[](2);
        for (uint256 i = 0; i < full_urs_g.length; i++) {
            bytes memory point_bytes = abi.decode(full_urs_g_serialized.values[i], (bytes));
            full_urs_g[i] = BN254.g1Deserialize(bytes32(point_bytes));
        }

        // deserialized and save h for both URS
        BN254.G1Point memory full_urs_h = BN254.g1Deserialize(bytes32(full_urs_h_serialized));

        // store values
        urs.g = full_urs_g;
        urs.h = full_urs_h;

        // deserialize and store lagrange bases
        // EncodedMap memory lagrange_b_serialized =
        //     abi.decode(find_value(full_urs_serialized, abi.encode("lagrange_bases")), (EncodedMap));
        // deser_lagrange_bases(lagrange_b_serialized, urs.lagrange_bases_unshifted);
    }

    function deser_linearization(Stream memory self, VerifierIndex storage index) public {
        // TODO: only constant_term is deserialized right now.
        EncodedArray memory arr = deser_arr32(self);

        PolishToken[] memory constant_term = new PolishToken[](arr.values.length);
        for (uint256 i = 0; i < arr.values.length; i++) {
            EncodedMap memory value_map = abi.decode(arr.values[i], (EncodedMap));
            constant_term[i] = deser_polishtoken(value_map);
        }

        index.linearization.constant_term = constant_term;
    }

    function deser_column(bytes memory col) public view returns (Column memory) {
        // if col is an encoded string, then it may be a unit value. In this case the encoded bytes
        // must not be more than 96 (this fact is based on seeing multiple encoded strings):
        // FIXME: this is hacky.
        if (col.length <= 96) {
            string memory variant = abi.decode(col, (string));
            if (Utils.str_cmp(variant, "Z")) {
                return Column(ColumnVariant.Z, new bytes(0));
            }
            if (Utils.str_cmp(variant, "LookupAggreg")) {
                return Column(ColumnVariant.LookupAggreg, new bytes(0));
            }
            if (Utils.str_cmp(variant, "LookupTable")) {
                return Column(ColumnVariant.LookupTable, new bytes(0));
            }
            if (Utils.str_cmp(variant, "LookupRuntimeSelector")) {
                return Column(ColumnVariant.LookupRuntimeSelector, new bytes(0));
            }
            if (Utils.str_cmp(variant, "LookupRuntimeTable")) {
                return Column(ColumnVariant.LookupRuntimeTable, new bytes(0));
            }
            revert UnmatchedGateType(variant);
        }

        // else, its an EncodedMap:
        EncodedMap memory col_map = abi.decode(col, (EncodedMap));
        (bytes memory witness_value, bool is_witness) = find_value_or_fail(col_map, abi.encode("Witness"));
        if (is_witness) {
            return Column(ColumnVariant.Witness, witness_value);
        }
        (bytes memory lookup_sorted_value, bool is_lookup_sorted) =
            find_value_or_fail(col_map, abi.encode("LookupSorted"));
        if (is_lookup_sorted) {
            return Column(ColumnVariant.LookupSorted, lookup_sorted_value);
        }
        (bytes memory lookup_kind_index_value, bool is_lookup_kind_index) =
            find_value_or_fail(col_map, abi.encode("LookupKindIndex"));
        if (is_lookup_kind_index) {
            string memory lookup_pattern_variant = abi.decode(lookup_kind_index_value, (string));
            if (Utils.str_cmp(lookup_pattern_variant, "Xor")) {
                return Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Xor));
            }
            if (Utils.str_cmp(lookup_pattern_variant, "Lookup")) {
                return Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.Lookup));
            }
            if (Utils.str_cmp(lookup_pattern_variant, "RangeCheck")) {
                return Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.RangeCheck));
            }
            if (Utils.str_cmp(lookup_pattern_variant, "ForeignFieldMul")) {
                return Column(ColumnVariant.LookupKindIndex, abi.encode(LookupPattern.ForeignFieldMul));
            }
        }
        (bytes memory index_value, bool is_index) = find_value_or_fail(col_map, abi.encode("Index"));
        if (is_index) {
            string memory gate_type_variant = abi.decode(index_value, (string));
            if (Utils.str_cmp(gate_type_variant, "Zero")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Zero));
            }
            if (Utils.str_cmp(gate_type_variant, "Generic")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Generic));
            }
            if (Utils.str_cmp(gate_type_variant, "Poseidon")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Poseidon));
            }
            if (Utils.str_cmp(gate_type_variant, "CompleteAdd")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.CompleteAdd));
            }
            if (Utils.str_cmp(gate_type_variant, "VarBaseMul")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.VarBaseMul));
            }
            if (Utils.str_cmp(gate_type_variant, "EndoMul")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.EndoMul));
            }
            if (Utils.str_cmp(gate_type_variant, "EndoMulScalar")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.EndoMulScalar));
            }
            if (Utils.str_cmp(gate_type_variant, "Lookup")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Lookup));
            }
            if (Utils.str_cmp(gate_type_variant, "RangeCheck0")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck0));
            }
            if (Utils.str_cmp(gate_type_variant, "RangeCheck1")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.RangeCheck1));
            }
            if (Utils.str_cmp(gate_type_variant, "ForeignFieldAdd")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldAdd));
            }
            if (Utils.str_cmp(gate_type_variant, "ForeignFieldMul")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldMul));
            }
            if (Utils.str_cmp(gate_type_variant, "Xor16")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Xor16));
            }
            if (Utils.str_cmp(gate_type_variant, "Rot64")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.Rot64));
            }
            revert UnmatchedGateType(gate_type_variant);
            // TODO: match remaining variants
        }
        (bytes memory coefficient_value, bool is_coefficient) = find_value_or_fail(col_map, abi.encode("Coefficient"));
        if (is_coefficient) {
            return Column(ColumnVariant.Coefficient, coefficient_value);
        }
        (bytes memory permutation_value, bool is_permutation) = find_value_or_fail(col_map, abi.encode("Permutation"));
        if (is_permutation) {
            return Column(ColumnVariant.Permutation, permutation_value);
        }
        revert("Couldn't match any Column variant while deserializing a column.");
        // TODO: remaining variants
    }

    function deser_polishtoken(EncodedMap memory map) public view returns (PolishToken memory) {
        // if its a unit variant (meaning that it doesn't have associated data):
        (bytes memory unit_value, bool is_unit) = find_value_or_fail(map, abi.encode("variant"));
        if (is_unit) {
            string memory variant = abi.decode(unit_value, (string));
            if (Utils.str_cmp(variant, "alpha")) {
                return PolishToken(PolishTokenVariant.Alpha, new bytes(0));
            } else if (Utils.str_cmp(variant, "beta")) {
                return PolishToken(PolishTokenVariant.Beta, new bytes(0));
            } else if (Utils.str_cmp(variant, "gamma")) {
                return PolishToken(PolishTokenVariant.Gamma, new bytes(0));
            } else if (Utils.str_cmp(variant, "jointcombiner")) {
                return PolishToken(PolishTokenVariant.JointCombiner, new bytes(0));
            } else if (Utils.str_cmp(variant, "endocoefficient")) {
                return PolishToken(PolishTokenVariant.EndoCoefficient, new bytes(0));
            } else if (Utils.str_cmp(variant, "dup")) {
                return PolishToken(PolishTokenVariant.Dup, new bytes(0));
            } else if (Utils.str_cmp(variant, "add")) {
                return PolishToken(PolishTokenVariant.Add, new bytes(0));
            } else if (Utils.str_cmp(variant, "mul")) {
                return PolishToken(PolishTokenVariant.Mul, new bytes(0));
            } else if (Utils.str_cmp(variant, "sub")) {
                return PolishToken(PolishTokenVariant.Sub, new bytes(0));
            } else if (Utils.str_cmp(variant, "vanishesonzeroknowledgeandpreviousrows")) {
                return PolishToken(PolishTokenVariant.VanishesOnZeroKnowledgeAndPreviousRows, new bytes(0));
            } else if (Utils.str_cmp(variant, "store")) {
                return PolishToken(PolishTokenVariant.Store, new bytes(0));
            }
        } else {
            (bytes memory mds_value, bool is_mds) = find_value_or_fail(map, abi.encode("mds"));
            if (is_mds) {
                EncodedMap memory mds_map = abi.decode(mds_value, (EncodedMap));
                uint256 row = abi.decode(find_value(mds_map, abi.encode("row")), (uint256));
                uint256 col = abi.decode(find_value(mds_map, abi.encode("col")), (uint256));
                return PolishToken(PolishTokenVariant.Mds, abi.encode(PolishTokenMds(row, col)));
            }
            (bytes memory literal_value, bool is_literal) = find_value_or_fail(map, abi.encode("literal"));
            if (is_literal) {
                // literal serializes as an array
                EncodedArray memory literal_arr = abi.decode(literal_value, (EncodedArray));
                uint256 inner_int = Utils.padded_le_bytes_array_to_uint256(literal_arr.values);
                return PolishToken(PolishTokenVariant.Literal, abi.encode(inner_int));
            }
            (bytes memory cell_value, bool is_cell) = find_value_or_fail(map, abi.encode("variable"));
            if (is_cell) {
                EncodedMap memory variable_map = abi.decode(cell_value, (EncodedMap));
                string memory row_str = abi.decode(find_value(variable_map, abi.encode("row")), (string));
                CurrOrNext row = CurrOrNext.Curr;
                if (Utils.str_cmp(row_str, "Curr")) {
                    row = CurrOrNext.Curr;
                } else if (Utils.str_cmp(row_str, "Next")) {
                    row = CurrOrNext.Next;
                } else {
                    revert("CurrOrNext didn't match any variant while deserializing linearization.");
                }
                Column memory col = deser_column(find_value(variable_map, abi.encode("col")));

                Variable memory variable = Variable(col, row);
                return PolishToken(PolishTokenVariant.Cell, abi.encode(variable));
            }
            (bytes memory pow_value, bool is_pow) = find_value_or_fail(map, abi.encode("pow"));
            if (is_pow) {
                uint256 pow = abi.decode(pow_value, (uint256));
                return PolishToken(PolishTokenVariant.Pow, abi.encode(pow));
            }
            (bytes memory ulag_value, bool is_ulag) = find_value_or_fail(map, abi.encode("rowoffset"));
            if (is_ulag) {
                return PolishToken(PolishTokenVariant.UnnormalizedLagrangeBasis, ulag_value);
            }
            (bytes memory load_value, bool is_load) = find_value_or_fail(map, abi.encode("load"));
            if (is_load) {
                uint256 i = abi.decode(load_value, (uint256));
                return PolishToken(PolishTokenVariant.Load, abi.encode(i));
            }
        }
    }

    /* WARN:
     * Functions below are part of the previous deserializer implementation,
     * and are still used for functions related to the demo. The goal is to replace
     * them with the new WIP deserializer. Please prefer using functions above.
     */

    function deserializeFinalCommitments(bytes calldata data)
        public
        pure
        returns (BN254.G1Point memory numerator, BN254.G1Point memory quotient, BN254.G2Point memory divisor)
    {
        numerator = abi.decode(data[:64], (BN254.G1Point));
        quotient = abi.decode(data[64:128], (BN254.G1Point));
        divisor = abi.decode(data[128:256], (BN254.G2Point));
    }

    /// @notice deserializes an array of G1Point and also returns the rest of the
    // data, excluding the consumed bytes. `i` is the index that we start to read
    // the data from.
    function deserializeG1Point(bytes calldata data, uint256 i)
        public
        view
        returns (BN254.G1Point memory p, uint256 final_i)
    {
        // read length of the data
        require(data[i] == 0xC4, "not a stream of bin8 (bytes)");

        // next byte is the length of the stream in one byte
        i += 1;
        require(data[i] == 0x20, "size of element is not 32 bytes");

        // read data
        i += 1;
        bytes32 compressed = abi.decode(data[i:i + 32], (bytes32));
        p = BN254.g1Deserialize(compressed);

        // go to next
        i += 32;

        final_i = i;
    }

    /// @notice deserializes an URS excluding the lagrange bases, and also
    // returns the final index which points at the end of the consumed data.
    function deserializeURS(bytes calldata data)
        public
        view
        returns (BN254.G1Point[] memory, BN254.G1Point memory, uint256)
    {
        uint256 i = 0;
        require(data[i] == 0x92, "not a fix array of two elements");

        i += 1;
        require(data[i] == 0xdc || data[i] == 0xdd, "not an array16 or array32");
        // 0xdc means that the next 2 bytes represent the size,
        // 0xdd means that the next 4 bytes represent the size.
        uint256 byte_count = data[i] == 0xdc ? 2 : 4;

        // next bytes are size of the array
        i += 1;
        uint256 size = uint256(bytes32(data[i:i + byte_count])) >> ((32 - byte_count) * 8);
        // shift is necessary because conversion pads with zeros to the left
        BN254.G1Point[] memory g = new BN254.G1Point[](size);
        i += byte_count;

        // read elements
        for (uint256 elem = 0; elem < size; elem++) {
            (BN254.G1Point memory p, uint256 new_index) = deserializeG1Point(data, i);
            g[elem] = p;
            i = new_index;
        }

        (BN254.G1Point memory h, uint256 final_i) = deserializeG1Point(data, i);
        final_i += 1;
        return (g, h, final_i);
    }

    function deserializeScalar(bytes calldata data, uint256 i)
        public
        pure
        returns (Scalar.FE scalar, uint256 final_i)
    {
        // read length of the data
        require(data[i] == 0xC4, "not a stream of bin8 (bytes)");

        // next byte is the length of the stream in one byte
        i += 1;
        require(data[i] == 0x20, "size of element is not 32 bytes");

        // read data
        i += 1;
        uint256 inner = abi.decode(data[i:i + 32], (uint256));
        scalar = Scalar.from(inner);

        // go to next
        i += 32;

        final_i = i;
    }

    function deserializePointEvals(bytes calldata data, uint256 i)
        public
        pure
        returns (PointEvaluations memory eval, uint256 final_i)
    {
        require(data[i] == 0x92, "not a fix array of two elements");
        i += 1;
        require(data[i] == 0x91, "not a fix array of one element");
        i += 1;

        (Scalar.FE zeta, uint256 i0) = deserializeScalar(data, i);
        i = i0;
        require(data[i] == 0x91, "not a fix array of one element");
        i += 1;
        (Scalar.FE zeta_omega, uint256 i1) = deserializeScalar(data, i);
        i = i1;

        eval = PointEvaluations(zeta, zeta_omega);
        final_i = i;
    }

    function deserializeState(bytes calldata data, uint256 i) public pure returns (State memory) {
        require(data[i] == 0x93, "not a fix array of three elements");
        i += 1;

        // Creator public key:
        require(data[i] == 0xd9, "not a str 8");
        i += 1;
        // next byte is the length of the stream in one byte
        uint8 size = uint8(data[i]);
        i += 1;
        string memory creator = string(data[i:i + size]);
        i += size;

        // State hash:
        require(data[i] == 0xd9, "not a str 8");
        i += 1;
        // next byte is the length of the stream in one byte
        size = uint8(data[i]);
        i += 1;
        string memory hash_str = string(data[i:i + size]);
        uint256 hash = Utils.str_to_uint(hash_str);
        i += size;

        // Block height:
        require((data[i] >> 4) == 0x0a, "not a fixstr");
        size = uint8(data[i]) & 0x0f;
        i += 1;
        string memory height_str = string(data[i:i + size]);
        uint256 block_height = Utils.str_to_uint(height_str);
        i += size;

        return State(creator, hash, block_height);
    }
}
