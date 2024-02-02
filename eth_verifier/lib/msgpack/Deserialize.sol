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

    error EncodedMapKeyNotFound(bytes key, bytes[] stored_keys);

    /// @notice returns the bytes corresponding to the queried key
    function find_value(EncodedMap memory self, bytes memory key) public pure returns (bytes memory) {
        uint256 i = 0;
        while (i != self.keys.length && keccak256(self.keys[i]) != keccak256(key)) {
            i++;
        }
        if (i == self.keys.length) revert EncodedMapKeyNotFound(key, self.keys);
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

    error NotImplementedType(bytes1 prefix);

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

        uint16 n = uint16(bytes2(next_n(self, 4)));

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
        require(first >> 2 == 0x33, "not a uint");
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

    function deser_null(Stream memory self) public pure returns (string memory) {
        bytes1 first = next(self);
        require(first == 0xc0, "not null");

        return "null";
    }

    // @notice checks if `self` corresponds to the encoding of a `null` string.
    function is_null(bytes memory self) public pure returns (bool) {
        bytes memory null_encoded = abi.encode("null");
        if (self.length != null_encoded.length) return false;

        for (uint i = 0; i < self.length; i++) {
            if (self[i] != null_encoded[i]) return false;
        }
        return true;
    }

    function deser_bool(Stream memory self) public pure returns (bool) {
        bytes1 first = next(self);
        require(first == 0xc2 || first == 0xc3, "not a bool");

        return first == 0xc3; // 0xc3 == true
    }

    // @notice `map` is the parent map which contains the field with key `name` and value PolyComm.
    function deser_poly_comm_from_map(EncodedMap memory map, string memory name) public view returns (PolyComm memory) {
        EncodedMap memory poly_comm_map =
            abi.decode(find_value(map, abi.encode(name)), (EncodedMap));
        return deser_poly_comm(poly_comm_map);
    }

    // @notice if the poly comm is not null, then it is set into `comm_reference` and `true` is returned.
    function deser_poly_comm_from_map_optional(EncodedMap memory map, string memory name) public view returns (bool, PolyComm memory) {
        bytes memory poly_comm_bytes = find_value(map, abi.encode(name));
        if (!is_null(poly_comm_bytes)) {
            return (true, deser_poly_comm(abi.decode(poly_comm_bytes, (EncodedMap))));
        }
        return (false, PolyComm(new BN254.G1Point[](0), BN254.point_at_inf()));
    }

    function deser_lookup_verifier_index(EncodedMap memory map, LookupVerifierIndex storage index) public {
        // lookup table
        EncodedArray memory lookup_table_arr = abi.decode(find_value(map, abi.encode("lookup_table")), (EncodedArray));
        uint lookup_table_len = lookup_table_arr.values.length;
        index.lookup_table = new PolyComm[](lookup_table_len);
        for (uint256 i = 0; i < lookup_table_len; i++) {
            index.lookup_table[i] = deser_poly_comm(abi.decode(lookup_table_arr.values[i], (EncodedMap)));
        }

        // lookup selectors
        EncodedMap memory selectors_map = abi.decode(find_value(map, abi.encode("lookup_selectors")), (EncodedMap));
        (
            index.lookup_selectors.is_xor_set,
            index.lookup_selectors.xor
        ) = deser_poly_comm_from_map_optional(selectors_map, "xor");
        (
            index.lookup_selectors.is_lookup_set,
            index.lookup_selectors.lookup
        ) = deser_poly_comm_from_map_optional(selectors_map, "lookup");
        (
            index.lookup_selectors.is_range_check_set,
            index.lookup_selectors.range_check
        ) = deser_poly_comm_from_map_optional(selectors_map, "range_check");
        (
            index.lookup_selectors.is_ffmul_set,
            index.lookup_selectors.ffmul
        ) = deser_poly_comm_from_map_optional(selectors_map, "ffmul");

        // table ids
        (
            index.is_table_ids_set,
            index.table_ids
        ) = deser_poly_comm_from_map_optional(map, "table_ids");

        // runtime table selectors
        (
            index.is_runtime_tables_selector_set,
            index.runtime_tables_selector
        ) = deser_poly_comm_from_map_optional(map, "runtime_tables_selector");
    }

    function deser_verifier_index(Stream memory self, VerifierIndex storage index) external {
        EncodedMap memory map = deser_map16(self);
        index.public_len = abi.decode(find_value(map, abi.encode("public")), (uint256));
        index.max_poly_size = abi.decode(find_value(map, abi.encode("max_poly_size")), (uint256));
        index.zk_rows = abi.decode(find_value(map, abi.encode("zk_rows")), (uint64));

        bytes memory domain_b = abi.decode(find_value(map, abi.encode("domain")), (bytes));

        // The domain info is in a packed, little endian serialization format.
        // So we'll need to manually deserialize the parameters that we're
        // interested in:

        // domain_size is 64 bit and the first element, so 8 bytes and no offset:
        index.domain_size = 0;
        for (uint64 i = 0; i < 8; i++) {
            index.domain_size += uint64(uint8(domain_b[i])) << (i * 8);
        }

        // domain_gen is 256 bit and there're 8+4+32+32=76 bytes before it:
        uint256 domain_gen = 0;
        for (uint256 i = 0; i < 32; i++) {
            domain_gen += uint256(uint8(domain_b[i + 76])) << (i * 8);
        }
        index.domain_gen = Scalar.from(domain_gen);

        // wire shift coordinates
        EncodedArray memory shift_arr = abi.decode(find_value(map, abi.encode("shift")), (EncodedArray));
        require(shift_arr.values.length == 7, "shift array is not of length 7");
        for (uint256 i = 0; i < 7; i++) {
            uint256 inner = uint256(bytes32(abi.decode(shift_arr.values[i], (bytes))));
            index.shift[i] = Scalar.from(inner);
        }

        // domain offset for zero-knowledge
        index.w = index.domain_gen.pow(index.domain_size - index.zk_rows);

        // commitments

        EncodedArray memory sigma_comm_arr = abi.decode(find_value(map, abi.encode("sigma_comm")), (EncodedArray));
        PolyComm[7] memory sigma_comm;
        for (uint256 i = 0; i < sigma_comm.length; i++) {
            sigma_comm[i] = deser_poly_comm(abi.decode(sigma_comm_arr.values[i], (EncodedMap)));
        }
        EncodedArray memory coefficients_comm_arr =
            abi.decode(find_value(map, abi.encode("coefficients_comm")), (EncodedArray));
        PolyComm[15] memory coefficients_comm;
        for (uint256 i = 0; i < coefficients_comm.length; i++) {
            coefficients_comm[i] = deser_poly_comm(abi.decode(coefficients_comm_arr.values[i], (EncodedMap)));
        }
        index.sigma_comm = sigma_comm;
        index.coefficients_comm = coefficients_comm;

        index.generic_comm = deser_poly_comm_from_map(map, "generic_comm");
        index.psm_comm = deser_poly_comm_from_map(map, "psm_comm");
        index.complete_add_comm = deser_poly_comm_from_map(map, "complete_add_comm");
        index.mul_comm = deser_poly_comm_from_map(map, "mul_comm");
        index.emul_comm = deser_poly_comm_from_map(map, "emul_comm");
        index.endomul_scalar_comm = deser_poly_comm_from_map(map, "endomul_scalar_comm");

        (
            index.is_range_check0_comm_set,
            index.range_check0_comm
        ) = deser_poly_comm_from_map_optional(map, "range_check0_comm");
        (
            index.is_range_check1_comm_set,
            index.range_check1_comm
        ) = deser_poly_comm_from_map_optional(map, "range_check1_comm");
        (
            index.is_foreign_field_add_comm_set,
            index.foreign_field_add_comm
        ) = deser_poly_comm_from_map_optional(map, "foreign_field_add_comm");
        (
            index.is_foreign_field_mul_comm_set,
            index.foreign_field_mul_comm
        ) = deser_poly_comm_from_map_optional(map, "foreign_field_mul_comm");
        (
            index.is_xor_comm_set,
            index.xor_comm
        ) = deser_poly_comm_from_map_optional(map, "xor_comm");
        (
            index.is_rot_comm_set,
            index.rot_comm
        ) = deser_poly_comm_from_map_optional(map, "rot_comm");

        // lookup index
        bytes memory lookup_index_bytes = find_value(map, abi.encode("lookup_index"));
        if (!is_null(lookup_index_bytes)) {
            EncodedMap memory lookup_index_map = abi.decode(lookup_index_bytes, (EncodedMap));
            deser_lookup_verifier_index(lookup_index_map, index.lookup_index);
            index.is_lookup_index_set = true;
        } else {
            index.is_lookup_index_set = false;
        }
    }

    function deser_poly_comm(EncodedMap memory map) public view returns (PolyComm memory) {
        EncodedArray memory unshifted_arr = abi.decode(find_value(map, abi.encode("unshifted")), (EncodedArray));

        uint256 len = unshifted_arr.values.length;
        BN254.G1Point[] memory unshifted = new BN254.G1Point[](len);
        for (uint256 i = 0; i < len; i++) {
            bytes memory comm_bytes = abi.decode(unshifted_arr.values[i], (bytes));
            unshifted[i] = BN254.g1Deserialize(bytes32(comm_bytes));
        }
        // TODO: shifted is fixed to infinity
        BN254.G1Point memory shifted = BN254.point_at_inf();
        return PolyComm(unshifted, shifted);
    }

    function deser_prover_proof(Stream memory self, ProverProof storage prover_proof) external {
        EncodedMap memory map = deser_fixmap(self);

        // deserialize evaluations

        EncodedMap memory all_evals_map = abi.decode(find_value(map, abi.encode("evals")), (EncodedMap));

        prover_proof.evals.public_evals = deser_evals(all_evals_map, "public");
        prover_proof.evals.is_public_evals_set = true;

        prover_proof.evals.z = deser_evals(all_evals_map, "z");

        PointEvaluationsArray[] memory w = deser_evals_array(all_evals_map, "w");
        for (uint256 i = 0; i < 15; i++) {
            prover_proof.evals.w[i] = w[i];
        }

        PointEvaluationsArray[] memory s = deser_evals_array(all_evals_map, "s");
        for (uint256 i = 0; i < 6; i++) {
            prover_proof.evals.w[i] = w[i];
        }

        // deserialize commitments

        EncodedMap memory comm_map = abi.decode(find_value(map, abi.encode("commitments")), (EncodedMap));

        EncodedArray memory w_comm_arr = abi.decode(find_value(comm_map, abi.encode("w_comm")), (EncodedArray));
        EncodedMap memory z_comm_map = abi.decode(find_value(comm_map, abi.encode("z_comm")), (EncodedMap));
        EncodedMap memory t_comm_map = abi.decode(find_value(comm_map, abi.encode("t_comm")), (EncodedMap));
        EncodedMap memory lookup_map = abi.decode(find_value(comm_map, abi.encode("lookup")), (EncodedMap));

        // witness commitments
        PolyComm[15] memory w_comm;
        for (uint256 i = 0; i < w_comm.length; i++) {
            w_comm[i] = deser_poly_comm(abi.decode(w_comm_arr.values[i], (EncodedMap)));
        }

        // permutation commitments
        PolyComm memory z_comm = deser_poly_comm(z_comm_map);

        // quotient commitments
        PolyComm memory t_comm = deser_poly_comm(t_comm_map);

        // lookup commitments
        EncodedArray memory sorted_arr = abi.decode(find_value(lookup_map, abi.encode("sorted")), (EncodedArray));
        EncodedMap memory aggreg_map = abi.decode(find_value(lookup_map, abi.encode("aggreg")), (EncodedMap));

        bytes memory runtime_bytes = find_value(lookup_map, abi.encode("runtime"));
        EncodedMap memory runtime_map;
        bool runtime_is_null = is_null(runtime_bytes);
        if (!runtime_is_null) {
            runtime_map = abi.decode(runtime_bytes, (EncodedMap));
        }

        PolyComm[] memory lookup_sorted = new PolyComm[](sorted_arr.values.length);
        for (uint256 i = 0; i < lookup_sorted.length; i++) {
            lookup_sorted[i] = deser_poly_comm(abi.decode(sorted_arr.values[i], (EncodedMap)));
        }
        PolyComm memory lookup_aggreg = deser_poly_comm(aggreg_map);

        PolyComm memory lookup_runtime;
        if (!runtime_is_null) {
            lookup_runtime = deser_poly_comm(runtime_map);
        }

        prover_proof.commitments.w_comm = w_comm;
        prover_proof.commitments.z_comm = z_comm;
        prover_proof.commitments.t_comm = t_comm;

        prover_proof.commitments.lookup.sorted = lookup_sorted;
        prover_proof.commitments.lookup.aggreg = lookup_aggreg;
        if (!runtime_is_null) {
            prover_proof.commitments.lookup.is_runtime_set = true;
            prover_proof.commitments.lookup.runtime = lookup_runtime;
        } else {
            prover_proof.commitments.lookup.is_runtime_set = false;
        }

        // deserialize opening proof

        EncodedMap memory proof_map = abi.decode(find_value(map, abi.encode("proof")), (EncodedMap));
        bytes memory quotient_bytes = abi.decode(find_value(proof_map, abi.encode("quotient")), (bytes));
        bytes memory blinding_bytes = abi.decode(find_value(proof_map, abi.encode("blinding")), (bytes));

        BN254.G1Point[] memory quotient_unshifted = new BN254.G1Point[](1);
        quotient_unshifted[0] = BN254.g1Deserialize(bytes32(quotient_bytes));

        Scalar.FE blinding = Scalar.from(uint256(bytes32(blinding_bytes)));

        prover_proof.opening.quotient.unshifted = quotient_unshifted;
        prover_proof.opening.blinding = blinding;
    }

    function deser_evals(EncodedMap memory all_evals_map, string memory name)
        public
        pure
        returns (PointEvaluationsArray memory)
    {
        EncodedMap memory eval_map = abi.decode(find_value(all_evals_map, abi.encode(name)), (EncodedMap));

        EncodedArray memory zeta_arr = abi.decode(find_value(eval_map, abi.encode("zeta")), (EncodedArray));
        EncodedArray memory zeta_omega_arr = abi.decode(find_value(eval_map, abi.encode("zeta_omega")), (EncodedArray));
        require(zeta_arr.values.length == zeta_omega_arr.values.length);
        uint256 length = zeta_arr.values.length;

        Scalar.FE[] memory zetas = new Scalar.FE[](length);
        Scalar.FE[] memory zeta_omegas = new Scalar.FE[](length);
        for (uint256 i = 0; i < zeta_arr.values.length; i++) {
            bytes memory zeta_bytes = abi.decode(zeta_arr.values[i], (bytes));
            bytes memory zeta_omega_bytes = abi.decode(zeta_omega_arr.values[i], (bytes));

            uint256 zeta_inner = uint256(bytes32(zeta_bytes));
            uint256 zeta_omega_inner = uint256(bytes32(zeta_omega_bytes));

            zetas[i] = Scalar.from(zeta_inner);
            zeta_omegas[i] = Scalar.from(zeta_omega_inner);
        }

        return PointEvaluationsArray(zetas, zeta_omegas);
    }

    function deser_evals_array(EncodedMap memory all_evals_map, string memory name)
        public
        pure
        returns (PointEvaluationsArray[] memory evals)
    {
        EncodedArray memory eval_array = abi.decode(find_value(all_evals_map, abi.encode(name)), (EncodedArray));
        uint256 length = eval_array.values.length;
        evals = new PointEvaluationsArray[](length);

        for (uint256 eval = 0; eval < length; eval++) {
            EncodedMap memory eval_map = abi.decode(eval_array.values[eval], (EncodedMap));

            EncodedArray memory zeta_arr = abi.decode(find_value(eval_map, abi.encode("zeta")), (EncodedArray));
            EncodedArray memory zeta_omega_arr =
                abi.decode(find_value(eval_map, abi.encode("zeta_omega")), (EncodedArray));
            require(zeta_arr.values.length == zeta_omega_arr.values.length);
            uint256 length = zeta_arr.values.length;

            Scalar.FE[] memory zetas = new Scalar.FE[](length);
            Scalar.FE[] memory zeta_omegas = new Scalar.FE[](length);
            for (uint256 i = 0; i < zeta_arr.values.length; i++) {
                bytes memory zeta_bytes = abi.decode(zeta_arr.values[i], (bytes));
                bytes memory zeta_omega_bytes = abi.decode(zeta_omega_arr.values[i], (bytes));

                uint256 zeta_inner = uint256(bytes32(zeta_bytes));
                uint256 zeta_omega_inner = uint256(bytes32(zeta_omega_bytes));

                zetas[i] = Scalar.from(zeta_inner);
                zeta_omegas[i] = Scalar.from(zeta_omega_inner);
            }
            evals[eval] = PointEvaluationsArray(zetas, zeta_omegas);
        }
    }

    function deser_lagrange_bases(
        EncodedMap memory map,
        mapping(uint256 => PolyCommFlat) storage lagrange_bases_unshifted
    ) public {
        for (uint256 i = 0; i < map.keys.length; i++) {
            EncodedArray memory comms = abi.decode(map.values[i], (EncodedArray));
            PolyComm[] memory polycomms = new PolyComm[](comms.values.length);

            for (uint256 j = 0; j < comms.values.length; j++) {
                EncodedMap memory comm = abi.decode(comms.values[i], (EncodedMap));
                EncodedArray memory unshifted_arr =
                    abi.decode(find_value(comm, abi.encode("unshifted")), (EncodedArray));

                uint256 unshifted_length = unshifted_arr.values.length;
                BN254.G1Point[] memory unshifted = new BN254.G1Point[](unshifted_length);
                for (uint256 k = 0; k < unshifted_length; k++) {
                    bytes memory unshifted_bytes = abi.decode(unshifted_arr.values[k], (bytes));
                    unshifted[k] = BN254.g1Deserialize(bytes32(unshifted_bytes));
                }

                // TODO: shifted is fixed to infinity
                BN254.G1Point memory shifted = BN254.point_at_inf();
                polycomms[j] = PolyComm(unshifted, shifted);
            }

            lagrange_bases_unshifted[abi.decode(map.keys[i], (uint256))] = poly_comm_flat(polycomms);
        }
    }

    // WARN: using the entire `full_urs` may not be necessary, we would only have to deserialize the
    // first two points (in the final verification step, we need the `full_urs` for commitment a
    // evaluation polynomial, which seems to be always of degree 1).
    function deser_pairing_urs(Stream memory self, PairingURS storage urs) public {
        // full_srs and verifier_srs fields
        EncodedMap memory urs_map = deser_fixmap(self);

        EncodedMap memory full_urs_serialized = abi.decode(find_value(urs_map, abi.encode("full_srs")), (EncodedMap));
        EncodedMap memory verifier_urs_serialized =
            abi.decode(find_value(urs_map, abi.encode("verifier_srs")), (EncodedMap));

        // get data from g and h fields (g is an array of bin8 and h is a bin8)
        EncodedArray memory full_urs_g_serialized =
            abi.decode(find_value(full_urs_serialized, abi.encode("g")), (EncodedArray));
        bytes memory full_urs_h_serialized = abi.decode(find_value(full_urs_serialized, abi.encode("h")), (bytes));

        EncodedArray memory verifier_urs_g_serialized =
            abi.decode(find_value(verifier_urs_serialized, abi.encode("g")), (EncodedArray));
        bytes memory verifier_urs_h_serialized =
            abi.decode(find_value(verifier_urs_serialized, abi.encode("h")), (bytes));

        // deserialized and save g for both URS
        // INFO: we only need the first two points
        BN254.G1Point[] memory full_urs_g = new BN254.G1Point[](2);
        for (uint256 i = 0; i < full_urs_g.length; i++) {
            bytes memory point_bytes = abi.decode(full_urs_g_serialized.values[i], (bytes));
            full_urs_g[i] = BN254.g1Deserialize(bytes32(point_bytes));
        }

        require(verifier_urs_g_serialized.values.length == 3, "verifier_urs doesn\'t have three elements");
        BN254.G2Point[] memory verifier_urs_g = new BN254.G2Point[](3);
        for (uint256 i = 0; i < verifier_urs_g.length; i++) {
            bytes memory point_bytes = abi.decode(verifier_urs_g_serialized.values[i], (bytes));
            verifier_urs_g[i] = BN256G2.G2Deserialize(point_bytes);
        }

        // deserialized and save h for both URS
        BN254.G1Point memory full_urs_h = BN254.g1Deserialize(bytes32(full_urs_h_serialized));
        BN254.G2Point memory verifier_urs_h = BN256G2.G2Deserialize(verifier_urs_h_serialized);

        // store values
        urs.full_urs.g = full_urs_g;
        urs.full_urs.h = full_urs_h;

        urs.verifier_urs.g = verifier_urs_g;
        urs.verifier_urs.h = verifier_urs_h;

        // deserialize and store lagrange bases
        // EncodedMap memory lagrange_b_serialized =
        //     abi.decode(find_value(full_urs_serialized, abi.encode("lagrange_bases")), (EncodedMap));
        // deser_lagrange_bases(lagrange_b_serialized, urs.lagrange_bases_unshifted);
    }

    function deser_linearization(Stream memory self) public view returns (Linearization memory) {
        // TODO: only constant_term is deserialized right now.
        EncodedArray memory arr = deser_arr32(self);

        PolishToken[] memory constant_term = new PolishToken[](arr.values.length);
        for (uint256 i = 0; i < arr.values.length; i++) {
            EncodedMap memory value_map = abi.decode(arr.values[i], (EncodedMap));
            constant_term[i] = deser_polishtoken(value_map);
        }
    }

    function deser_column(bytes memory col) public pure returns (Column memory) {
        // if col is an encoded string, then it may be a unit value. In this case the encoded bytes
        // must not be more than 32:
        if (col.length <= 32) {
            string memory variant = abi.decode(col, (string));
            if (Utils.str_cmp(variant, "Z")) {
                return Column(ColumnVariant.Z, new bytes(0));
            }
        }
        // FIXME: this is hacky.

        // else, its an EncodedMap:
        EncodedMap memory col_map = abi.decode(col, (EncodedMap));
        (bytes memory witness_value, bool is_witness) = find_value_or_fail(col_map, abi.encode("Witness"));
        if (is_witness) {
            return Column(ColumnVariant.Witness, witness_value);
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
            if (Utils.str_cmp(gate_type_variant, "ForeignFieldAdd")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldAdd));
            }
            if (Utils.str_cmp(gate_type_variant, "ForeignFieldMul")) {
                return Column(ColumnVariant.Index, abi.encode(GateType.ForeignFieldMul));
            }
            revert("Couldn't match any GateType variant while deserializing a column.");
            // TODO: match remaining variants
        }
        (bytes memory coefficient_value, bool is_coefficient) = find_value_or_fail(col_map, abi.encode("Coefficient"));
        if (is_coefficient) {
            uint256 i = deser_uint(new_stream(coefficient_value));
            return Column(ColumnVariant.Coefficient, abi.encode(i));
        }
        (bytes memory permutation_value, bool is_permutation) = find_value_or_fail(col_map, abi.encode("Permutation"));
        if (is_permutation) {
            uint256 i = deser_uint(new_stream(permutation_value));
            return Column(ColumnVariant.Permutation, abi.encode(i));
        }
        revert("Couldn't match any Column variant while deserializing a column.");
        // TODO: remaining variants
    }

    function deser_polishtoken(EncodedMap memory map) public pure returns (PolishToken memory) {
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
                EncodedArray memory literal_arr = abi.decode(literal_value, (EncodedArray));
                uint256 inner_int = Utils.padded_bytes_array_to_uint256(literal_arr.values);
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
                uint256 pow = deser_uint(new_stream(pow_value));
                return PolishToken(PolishTokenVariant.Pow, abi.encode(pow));
            }
            (bytes memory ulag_value, bool is_ulag) = find_value_or_fail(map, abi.encode("unnormalizedlagrangebasis"));
            if (is_ulag) {
                EncodedMap memory rowoffset_map = abi.decode(ulag_value, (EncodedMap));
                bool zk_rows = abi.decode(find_value(rowoffset_map, abi.encode("zk_rows")), (bool));
                int256 offset = abi.decode(find_value(rowoffset_map, abi.encode("offset")), (int256));
                RowOffset memory rowoffset = RowOffset(zk_rows, offset);
                return PolishToken(PolishTokenVariant.UnnormalizedLagrangeBasis, abi.encode(rowoffset));
            }
            (bytes memory load_value, bool is_load) = find_value_or_fail(map, abi.encode("load"));
            if (is_load) {
                uint256 i = deser_uint(new_stream(load_value));
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

    function deserializeProofEvaluationsArray(bytes calldata data, uint256 i)
        public
        pure
        returns (ProofEvaluationsArray memory evals, uint256 final_i)
    {
        // WARN: This works because the test circuit evaluations have one elem per array.
        (PointEvaluations memory evals_non_array, uint256 _i) = deserializePointEvals(data, i);

        Scalar.FE[] memory zeta = new Scalar.FE[](1);
        Scalar.FE[] memory zeta_omega = new Scalar.FE[](1);
        zeta[0] = evals_non_array.zeta;
        zeta_omega[0] = evals_non_array.zeta_omega;

        PointEvaluationsArray memory public_evals = PointEvaluationsArray(zeta, zeta_omega);

        PointEvaluationsArray[15] memory w;
        Scalar.FE[] memory zero = new Scalar.FE[](1);
        zero[0] = Scalar.zero();
        PointEvaluationsArray memory z = PointEvaluationsArray(zero, zero);
        PointEvaluationsArray[7 - 1] memory s;

        // array needed to simulate an optional param
        evals = ProofEvaluationsArray(public_evals, true, w, z, s);
        final_i = _i;
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
