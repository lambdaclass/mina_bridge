// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Kimchi} from "../../src/Verifier.sol";
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

    function new_stream(bytes calldata data)
        public
        pure
        returns (Stream memory)
    {
        return Stream(data, 0);
    }

    /// @notice returns current byte and advances index.
    function next(Stream memory self) public view returns (bytes1 b) {
        b = self.data[self.curr_index];
        self.curr_index += 1;
    }

    /// @notice returns current byte without advancing index.
    function curr(Stream memory self) public view returns (bytes1) {
        return self.data[self.curr_index];
    }

    function next_n(Stream memory self, uint256 n)
        public
        view
        returns (bytes memory consumed)
    {
        consumed = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            consumed[i] = self.data[self.curr_index + i];
        }
        self.curr_index += n;
    }

    error EncodedMapKeyNotFound(bytes key, bytes[] stored_keys);

    /// @notice returns the bytes corresponding to the queried key
    function find_value(EncodedMap memory self, bytes memory key)
        public
        pure
        returns (bytes memory)
    {
        uint256 i = 0;
        while (
            i != self.keys.length &&
            keccak256(self.keys[i]) != keccak256(key)
        ) {
            i++;
        }
        if (i == self.keys.length) revert EncodedMapKeyNotFound(key, self.keys);
        return self.values[i];
    }

    /// @notice like find_value() but returns a boolean that indicates if
    /// @notice the key exists. If not found, the resulted bytes will be empty.
    function find_value_or_fail(EncodedMap memory self, bytes memory key)
        public
        pure
        returns (bytes memory, bool)
    {
        uint256 i = 0;
        while (
            i != self.keys.length &&
            keccak256(self.keys[i]) != keccak256(key)
        ) {
            i++;
        }
        if (i == self.keys.length) return (new bytes(0), false);
        return (self.values[i], true);
    }

    error NotImplementedType(bytes1 prefix);

    /// @notice deserializes the next type and returns the encoded data.
    function deser_encode(Stream memory self)
        public
        view
        returns (bytes memory)
    {
        bytes1 prefix = curr(self);
        if (
            prefix >> 5 == 0x05 ||
            prefix == 0xd9 ||
            prefix == 0xda ||
            prefix == 0xdb
        ) {
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

    function deser_str(Stream memory self) public view returns (string memory) {
        bytes1 first = next(self);
        require(
            first >> 5 == 0x05 ||
                first == 0xd9 ||
                first == 0xda ||
                first == 0xdb,
            "not a fixstr or strX"
        );

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

    function deser_bin8(Stream memory self) public view returns (bytes memory) {
        require(next(self) == 0xC4, "not a stream of bin8 (bytes)");

        // next byte is the length of the stream in one byte
        uint256 n = uint256(uint8(next(self)));

        // read data
        return next_n(self, n);
    }

    function deser_fixarr(Stream memory self)
        public
        view
        returns (EncodedArray memory arr)
    {
        bytes1 first = next(self);
        require(first >> 4 == 0x09, "not a fixarr");
        uint256 n = uint256(uint8(first & 0x0F)); // low nibble

        arr = EncodedArray(new bytes[](n));

        for (uint256 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_fixmap(Stream memory self)
        public
        view
        returns (EncodedMap memory map)
    {
        bytes1 first = next(self);
        require(first >> 4 == 0x08, "not a fixmap");
        uint256 n = uint256(uint8(first & 0x0F)); // low nibble

        map = EncodedMap(new bytes[](n), new bytes[](n));

        for (uint256 i = 0; i < n; i++) {
            map.keys[i] = deser_encode(self);
            map.values[i] = deser_encode(self);
        }
    }

    function deser_arr16(Stream memory self)
        public
        view
        returns (EncodedArray memory arr)
    {
        bytes1 first = next(self);
        require(first == 0xdc, "not an arr16");
        // size is next two bytes:

        uint16 n = uint16(bytes2(next_n(self, 2)));

        arr = EncodedArray(new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_arr32(Stream memory self)
        public
        view
        returns (EncodedArray memory arr)
    {
        bytes1 first = next(self);
        require(first == 0xdd, "not an arr32");
        // size is next two bytes:

        uint16 n = uint16(bytes2(next_n(self, 4)));

        arr = EncodedArray(new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            arr.values[i] = deser_encode(self);
        }
    }

    function deser_map16(Stream memory self)
        public
        view
        returns (EncodedMap memory map)
    {
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

    function deser_uint(Stream memory self) public view returns (uint256) {
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

    function deser_posfixint(Stream memory self) public view returns (uint8) {
        bytes1 first = next(self);
        require(first >> 7 == 0x00, "not a positive fixint");

        return uint8(first);
    }

    function deser_null(Stream memory self)
        public
        view
        returns (string memory)
    {
        bytes1 first = next(self);
        require(first == 0xc0, "not null");

        return "null";
    }

    function deser_bool(Stream memory self) public view returns (bool) {
        bytes1 first = next(self);
        require(first == 0xc2 || first == 0xc3, "not a bool");

        return first == 0xc3; // 0xc3 == true
    }

    function deser_buffer(EncodedMap memory self)
        public
        pure
        returns (bytes memory data)
    {
        bytes memory type_name = abi.decode(find_value(self, abi.encode("type")), (bytes));
        require(keccak256(type_name) == keccak256("Buffer"));

        EncodedArray memory data_arr = abi.decode(
            find_value(self, abi.encode("data")),
            (EncodedArray)
        );

        // data_arr will hold an array of `bytes` arrays, where each `bytes`
        // is a 32 sized byte array which represents only one byte, but padded
        // with 31 zero bytes. e.g:
        // data_arr[0]: 0x00000000000000000000000000000000000000000000000000000000000000a7
        // data_arr[1]: 0x0000000000000000000000000000000000000000000000000000000000000040
        // data_arr[3]: 0x000000000000000000000000000000000000000000000000000000000000002e
        //
        // this is becasue of Solidity's RLP encoding of every byte.
        // We're interested in removing this padding and flattening all the arrays:

        data = Utils.flatten_padded_bytes_array(data_arr.values);
    }

    function deser_buffer_to_uint256(EncodedMap memory self)
        public
        pure
        returns (uint256 integer)
    {
        bytes memory type_name = abi.decode(find_value(self, abi.encode("type")), (bytes));
        require(keccak256(type_name) == keccak256("Buffer"));

        EncodedArray memory data_arr = abi.decode(
            find_value(self, abi.encode("data")),
            (EncodedArray)
        );

        integer = Utils.padded_bytes_array_to_uint256(data_arr.values);
    }

    function deser_verifier_index(
        Stream memory self,
        VerifierIndex storage index
    ) external {
        EncodedMap memory map = deser_map16(self);
        index.public_len = abi.decode(find_value(map, abi.encode("public")), (uint256));
        index.max_poly_size = abi.decode(
            find_value(map, abi.encode("max_poly_size")),
            (uint256)
        );
        index.zk_rows = abi.decode(find_value(map, abi.encode("zk_rows")), (uint64));

        EncodedMap memory domain_map = abi.decode(
            find_value(map, abi.encode("domain")),
            (EncodedMap)
        );

        bytes memory domain_b = deser_buffer(domain_map);

        // The domain info is in a packed, little endian serialization format.
        // So we'll need to manually deserialize the parameters that we're
        // interested in:

        // domain_size is 64 bit and the first element, so 8 bytes and no offset:
        index.domain_size = 0;
        for (uint256 i = 0; i < 8; i++) {
            index.domain_size += uint64(uint8(domain_b[i])) << (i * 8);
        }

        // domain_gen is 256 bit and there're 8+4+32+32=76 bytes before it:
        uint256 domain_gen = 0;
        for (uint256 i = 0; i < 32; i++) {
            domain_gen += uint256(uint8(domain_b[i + 76])) << (i * 8);
        }
        index.domain_gen = Scalar.from(domain_gen);

        // wire shift coordinates
        EncodedArray memory shift_arr = abi.decode(
            find_value(map, abi.encode("shift")),
            (EncodedArray)
        );
        require(shift_arr.values.length == 7, "shift array is not of length 7");
        for (uint256 i = 0; i < 7; i++) {
            uint256 inner = deser_buffer_to_uint256(
                abi.decode(shift_arr.values[i], (EncodedMap))
            );
            index.shift[i] = Scalar.from(inner);
        }

        // domain offset for zero-knowledge
        index.w = index.domain_gen.pow(index.domain_size - index.zk_rows);

        // commitments
        EncodedArray memory sigma_comm_arr = abi.decode(
            find_value(map, abi.encode("sigma_comm")),
            (EncodedArray)
        );
        EncodedArray memory coefficients_comm_arr = abi.decode(
            find_value(map, abi.encode("coefficients_comm")),
            (EncodedArray)
        );

        PolyComm[7] memory sigma_comm;
        for (uint i = 0; i < sigma_comm.length; i++) {
            sigma_comm[i] = deser_poly_comm(abi.decode(
                sigma_comm_arr.values[i],
                (EncodedMap))
            );
        }

        PolyComm[15] memory coefficients_comm;
        for (uint i = 0; i < coefficients_comm.length; i++) {
            coefficients_comm[i] = deser_poly_comm(abi.decode(
                coefficients_comm_arr.values[i],
                (EncodedMap))
            );
        }

        index.sigma_comm = sigma_comm;
        index.coefficients_comm = coefficients_comm;
    }

    function deser_poly_comm(EncodedMap memory map)
        public
        view
        returns (PolyComm memory) 
    {
        EncodedArray memory unshifted_arr = abi.decode(
            find_value(map, abi.encode("unshifted")),
            (EncodedArray)
        );

        uint len = unshifted_arr.values.length;
        BN254.G1Point[] memory unshifted = new BN254.G1Point[](len);
        for (uint i = 0; i < len; i++) {
            EncodedMap memory buffer = abi.decode(
                unshifted_arr.values[i],
                (EncodedMap)
            );
            unshifted[i] = BN254.g1Deserialize(bytes32(deser_buffer(buffer)));
        }
        // TODO: shifted part

        return PolyComm(unshifted);
    }

    function deser_prover_proof(
        Stream memory self,
        ProverProof storage prover_proof
    ) external {
        EncodedMap memory map = deser_fixmap(self);

        // deserialize evaluations

        EncodedMap memory all_evals_map = abi.decode(
            find_value(map, abi.encode("evals")),
            (EncodedMap)
        );

        prover_proof.evals.public_evals = deser_evals(all_evals_map, "public");
        prover_proof.evals.is_public_evals_set = true;

        prover_proof.evals.z = deser_evals(all_evals_map, "z");

        PointEvaluationsArray[] memory w = deser_evals_array(
            all_evals_map,
            "w"
        );
        for (uint256 i = 0; i < 15; i++) {
            prover_proof.evals.w[i] = w[i];
        }

        PointEvaluationsArray[] memory s = deser_evals_array(
            all_evals_map,
            "s"
        );
        for (uint256 i = 0; i < 6; i++) {
            prover_proof.evals.w[i] = w[i];
        }

        // deserialize commitments

        EncodedMap memory comm_map = abi.decode(
            find_value(map, abi.encode("commitments")),
            (EncodedMap)
        );

        EncodedArray memory w_comm_arr = abi.decode(
            find_value(comm_map, abi.encode("w_comm")),
            (EncodedArray)
        );
        EncodedMap memory z_comm_map = abi.decode(
            find_value(comm_map, abi.encode("z_comm")),
            (EncodedMap)
        );
        EncodedMap memory t_comm_map = abi.decode(
            find_value(comm_map, abi.encode("t_comm")),
            (EncodedMap)
        );

        PolyComm[15] memory w_comm;
        for (uint i = 0; i < w_comm.length; i++) {
            w_comm[i] = deser_poly_comm(abi.decode(
                w_comm_arr.values[i]
                (EncodedMap))
            );
        }
        PolyComm memory z_comm = deser_poly_comm(z_comm_map);
        PolyComm memory t_comm = deser_poly_comm(t_comm_map);

        prover_proof.commitments.w_comm = w_comm;
        prover_proof.commitments.z_comm = z_comm;
        prover_proof.commitments.t_comm = t_comm;
    }

    function deser_evals(EncodedMap memory all_evals_map, string memory name)
        public
        pure
        returns (PointEvaluationsArray memory)
    {
        EncodedMap memory eval_map = abi.decode(
            find_value(all_evals_map, abi.encode(name)),
            (EncodedMap)
        );

        EncodedArray memory zeta_arr = abi.decode(
            find_value(eval_map, abi.encode("zeta")),
            (EncodedArray)
        );
        EncodedArray memory zeta_omega_arr = abi.decode(
            find_value(eval_map, abi.encode("zeta_omega")),
            (EncodedArray)
        );
        require(zeta_arr.values.length == zeta_omega_arr.values.length);
        uint256 length = zeta_arr.values.length;

        Scalar.FE[] memory zetas = new Scalar.FE[](length);
        Scalar.FE[] memory zeta_omegas = new Scalar.FE[](length);
        for (uint256 i = 0; i < zeta_arr.values.length; i++) {
            EncodedMap memory zeta_map = abi.decode(
                zeta_arr.values[i],
                (EncodedMap)
            );
            EncodedMap memory zeta_omega_map = abi.decode(
                zeta_omega_arr.values[i],
                (EncodedMap)
            );

            uint256 zeta_inner = deser_buffer_to_uint256(zeta_map);
            uint256 zeta_omega_inner = deser_buffer_to_uint256(zeta_omega_map);

            zetas[i] = Scalar.from(zeta_inner);
            zeta_omegas[i] = Scalar.from(zeta_omega_inner);
        }

        return PointEvaluationsArray(zetas, zeta_omegas);
    }

    function deser_evals_array(
        EncodedMap memory all_evals_map,
        string memory name
    ) public pure returns (PointEvaluationsArray[] memory evals) {
        EncodedArray memory eval_array = abi.decode(
            find_value(all_evals_map, abi.encode(name)),
            (EncodedArray)
        );
        uint256 length = eval_array.values.length;
        evals = new PointEvaluationsArray[](length);

        for (uint256 eval = 0; eval < length; eval++) {
            EncodedMap memory eval_map = abi.decode(
                eval_array.values[eval],
                (EncodedMap)
            );

            EncodedArray memory zeta_arr = abi.decode(
                find_value(eval_map, abi.encode("zeta")),
                (EncodedArray)
            );
            EncodedArray memory zeta_omega_arr = abi.decode(
                find_value(eval_map, abi.encode("zeta_omega")),
                (EncodedArray)
            );
            require(zeta_arr.values.length == zeta_omega_arr.values.length);
            uint256 length = zeta_arr.values.length;

            Scalar.FE[] memory zetas = new Scalar.FE[](length);
            Scalar.FE[] memory zeta_omegas = new Scalar.FE[](length);
            for (uint256 i = 0; i < zeta_arr.values.length; i++) {
                EncodedMap memory zeta_map = abi.decode(
                    zeta_arr.values[i],
                    (EncodedMap)
                );
                EncodedMap memory zeta_omega_map = abi.decode(
                    zeta_omega_arr.values[i],
                    (EncodedMap)
                );

                uint256 zeta_inner = deser_buffer_to_uint256(zeta_map);
                uint256 zeta_omega_inner = deser_buffer_to_uint256(
                    zeta_omega_map
                );

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
        for (uint i = 0; i < map.keys.length; i++) {
            EncodedArray memory comms = abi.decode(map.values[i], (EncodedArray));
            PolyComm[] memory polycomms = new PolyComm[](comms.values.length);

            for (uint j = 0; j < comms.values.length; j++) {
                EncodedMap memory comm = abi.decode(comms.values[i], (EncodedMap));
                EncodedArray memory unshifted_arr = abi.decode(find_value(comm, abi.encode("unshifted")), (EncodedArray));

                uint unshifted_length = unshifted_arr.values.length;
                BN254.G1Point[] memory unshifted = new BN254.G1Point[](unshifted_length);
                for (uint k = 0; k < unshifted_length; k++) {
                    EncodedMap memory unshifted_buffer = abi.decode(unshifted_arr.values[k], (EncodedMap));
                    unshifted[k] = BN254.g1Deserialize(bytes32(deser_buffer(unshifted_buffer)));
                }

                polycomms[j] = PolyComm(unshifted);
            }
            lagrange_bases_unshifted[abi.decode(map.keys[i], (uint256))] = poly_comm_flat(polycomms);
        }
    }

    // WARN: using the full urs may not be necessary, so we would only have to deserialize
    // the `verifier_urs` (which is only made of three points) and the lagrange bases.
    function deser_pairing_urs(Stream memory self, PairingURS storage urs) public {
        // full_srs and verifier_srs fields
        EncodedMap memory urs_map = deser_fixmap(self);

        EncodedMap memory full_urs_serialized = abi.decode(find_value(urs_map, abi.encode("full_srs")), (EncodedMap));
        EncodedMap memory verifier_urs_serialized = abi.decode(find_value(urs_map, abi.encode("verifier_srs")), (EncodedMap));

        // get data from g and h fields (g is an array of buffers and h is a buffer)
        EncodedArray memory full_urs_g_serialized = abi.decode(find_value(full_urs_serialized, abi.encode("g")), (EncodedArray));
        EncodedMap memory full_urs_h_serialized = abi.decode(find_value(full_urs_serialized, abi.encode("h")), (EncodedMap));

        EncodedArray memory verifier_urs_g_serialized = abi.decode(find_value(verifier_urs_serialized, abi.encode("g")), (EncodedArray));
        EncodedMap memory verifier_urs_h_serialized = abi.decode(find_value(verifier_urs_serialized, abi.encode("h")), (EncodedMap));

        // deserialized and save g for both URS
        uint full_urs_g_length = full_urs_g_serialized.values.length;
        BN254.G1Point[] memory full_urs_g = new BN254.G1Point[](full_urs_g_length);
        for (uint i = 0; i < full_urs_g_length; i++) {
            full_urs_g[i] = BN254.g1Deserialize(bytes32(deser_buffer(abi.decode(full_urs_g_serialized.values[i], (EncodedMap)))));
        }

        uint verifier_urs_g_length = verifier_urs_g_serialized.values.length;
        BN254.G1Point[] memory verifier_urs_g = new BN254.G1Point[](verifier_urs_g_length);
        for (uint i = 0; i < verifier_urs_g_length; i++) {
            verifier_urs_g[i] = BN254.g1Deserialize(bytes32(deser_buffer(abi.decode(verifier_urs_g_serialized.values[i], (EncodedMap)))));
        }

        // deserialized and save h for both URS
        BN254.G1Point memory full_urs_h = BN254.g1Deserialize(bytes32(deser_buffer(full_urs_h_serialized)));
        BN254.G1Point memory verifier_urs_h = BN254.g1Deserialize(bytes32(deser_buffer(verifier_urs_h_serialized)));

        // store values
        urs.full_urs.g = full_urs_g;
        urs.full_urs.h = full_urs_h;

        urs.verifier_urs.g = verifier_urs_g;
        urs.verifier_urs.h = verifier_urs_h;

        // deserialize and store lagrange bases
        EncodedMap memory lagrange_b_serialized = abi.decode(find_value(full_urs_serialized, abi.encode("lagrange_bases")), (EncodedMap));
        deser_lagrange_bases(lagrange_b_serialized, urs.lagrange_bases_unshifted);
    }

    function deser_linearization(Stream memory self) public pure returns (Linearization memory) {
        // TODO: only constant_term is deserialized right now.
        EncodedArray memory arr = deser_arr32(self);

        PolishToken[] memory constant_term = new PolishToken[](arr.values.length);
        for (uint i = 0; i < arr.values.length; i++) {
            EncodedMap memory value_map = abi.decode(arr.values[i], (EncodedMap));
            // if its a unit variant (meaning that it doesn't have associated data):
            (bytes memory value, bool is_unit) = find_value_or_fail(value_map, abi.encode("variant"));
            if (is_unit) {
                string memory variant = abi.decode(value, (string));
                if (Utils.str_cmp(variant, "alpha")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Alpha, new bytes(0));
                } else if (Utils.str_cmp(variant, "beta")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Beta, new bytes(0));
                } else if (Utils.str_cmp(variant, "gamma")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Gamma, new bytes(0));
                } else if (Utils.str_cmp(variant, "jointcombiner")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.JointCombiner, new bytes(0));
                } else if (Utils.str_cmp(variant, "endocoefficient")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.EndoCoefficient, new bytes(0));
                } else if (Utils.str_cmp(variant, "dup")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Dup, new bytes(0));
                } else if (Utils.str_cmp(variant, "Add")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Add, new bytes(0));
                } else if (Utils.str_cmp(variant, "Mul")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Mul, new bytes(0));
                } else if (Utils.str_cmp(variant, "Sub")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Sub, new bytes(0));
                } else if (Utils.str_cmp(variant, "vanishesonzeroknowledgeandpreviousrows")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.VanishesOnZeroKnowledgeAndPreviousRows, new bytes(0));
                } else if (Utils.str_cmp(variant, "store")) {
                    constant_term[i] = PolishToken(PolishTokenVariant.Store, new bytes(0));
                }
            }

        }
    }

    function deser_polishtoken(Encoded)

    //  !!! FUNCTIONS BELOW ARE DEPRECATED !!!

    function deserializeFinalCommitments(bytes calldata data)
        public
        view
        returns (
            BN254.G1Point memory numerator,
            BN254.G1Point memory quotient,
            BN254.G2Point memory divisor
        )
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
        returns (
            BN254.G1Point[] memory,
            BN254.G1Point memory,
            uint256
        )
    {
        uint256 i = 0;
        require(data[i] == 0x92, "not a fix array of two elements");

        i += 1;
        require(
            data[i] == 0xdc || data[i] == 0xdd,
            "not an array16 or array32"
        );
        // 0xdc means that the next 2 bytes represent the size,
        // 0xdd means that the next 4 bytes represent the size.
        uint256 byte_count = data[i] == 0xdc ? 2 : 4;

        // next bytes are size of the array
        i += 1;
        uint256 size = uint256(bytes32(data[i:i + byte_count])) >>
            ((32 - byte_count) * 8);
        // shift is necessary because conversion pads with zeros to the left
        BN254.G1Point[] memory g = new BN254.G1Point[](size);
        i += byte_count;

        // read elements
        for (uint256 elem = 0; elem < size; elem++) {
            (BN254.G1Point memory p, uint256 new_index) = deserializeG1Point(
                data,
                i
            );
            g[elem] = p;
            i = new_index;
        }

        (BN254.G1Point memory h, uint256 final_i) = deserializeG1Point(data, i);
        final_i += 1;
        return (g, h, final_i);
    }

    function deserializeOpeningProof(bytes calldata serialized_proof)
        public
        view
        returns (Kimchi.ProverProof memory proof)
    {
        uint256 i = 0;
        bytes1 firstbyte = serialized_proof[i];
        // first byte is 0x92, indicating this is an array with 2 elements
        require(firstbyte == 0x92, "first byte is not 0x92");

        // read length of the data
        i += 1;
        require(serialized_proof[i] == 0xC4, "second byte is not 0xC4");

        // next byte is the length of the data in one byte
        i += 1;
        require(serialized_proof[i] == 0x20, "size of element is not 32 bytes");

        // read data
        i += 1;
        bytes32 data_quotient = abi.decode(
            serialized_proof[i:i + 32],
            (bytes32)
        );

        proof.opening_proof_quotient = BN254.g1Deserialize(data_quotient);

        // read blinding
        i += 32;
        // read length of the data
        require(serialized_proof[i] == 0xC4, "second byte is not 0xC4");

        // next byte is the length of the data in one byte
        i += 1;
        require(serialized_proof[i] == 0x20, "size of element is not 32 bytes");

        // read data
        i += 1;
        uint256 data_blinding = abi.decode(
            serialized_proof[i:i + 32],
            (uint256)
        );

        proof.opening_proof_blinding = data_blinding;
        return proof;
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
        (
            PointEvaluations memory evals_non_array,
            uint256 _i
        ) = deserializePointEvals(data, i);

        Scalar.FE[] memory zeta = new Scalar.FE[](1);
        Scalar.FE[] memory zeta_omega = new Scalar.FE[](1);
        zeta[0] = evals_non_array.zeta;
        zeta_omega[0] = evals_non_array.zeta_omega;

        PointEvaluationsArray memory public_evals = PointEvaluationsArray(
            zeta,
            zeta_omega
        );

        PointEvaluationsArray[15] memory w;
        Scalar.FE[] memory zero = new Scalar.FE[](1);
        zero[0] = Scalar.zero();
        PointEvaluationsArray memory z = PointEvaluationsArray(zero, zero);
        PointEvaluationsArray[7 - 1] memory s;

        // array needed to simulate an optional param
        evals = ProofEvaluationsArray(public_evals, true, w, z, s);
        final_i = _i;
    }

    function deserializeState(bytes calldata data, uint256 i)
        public
        view
        returns (State memory)
    {
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
