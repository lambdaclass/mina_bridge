// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Kimchi} from "../../src/Verifier.sol";
import "../Commitment.sol";
import "../bn254/BN254.sol";
import "../Evaluations.sol";
import "../Proof.sol";
import "../State.sol";
import "../Utils.sol";
import "../VerifierIndex.sol";
import "forge-std/console.sol";

library MsgPk {
    struct Stream {
        bytes data;
        uint256 curr_index;
    }

    struct EncodedArray {
        bytes[] values;
    }

    struct EncodedMap {
        string[] keys;
        bytes[] values;
    }

    function from_data(bytes calldata data)
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

    error NotImplementedType(bytes1 prefix);

    /// @notice deserializes the next type and returns the encoded data.
    function deser_encode(Stream memory self)
        public
        view
        returns (bytes memory)
    {
        bytes1 prefix = curr(self);
        if (prefix >> 5 == 0x05) {
            return abi.encode(deser_fixstr(self));
        } else if (prefix == 0xC4) {
            return abi.encode(deser_bin8(self));
        } else if (prefix >> 4 == 0x08) {
            return abi.encode(deser_fixmap(self));
        } else if (prefix >> 4 == 0x09) {
            return abi.encode(deser_fixarr(self));
        } else if (prefix >> 2 == 0x33) {
            return abi.encode(deser_uint(self));
        } else if (prefix >> 7 == 0x00) {
            return abi.encode(deser_posfixint(self));
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

    function deser_fixstr(Stream memory self)
        public
        view
        returns (string memory)
    {
        bytes1 first = next(self);
        require(first >> 5 == 0x05, "not a fixstr");
        uint256 n = uint256(uint8(first & 0x1F)); // low nibble + lsb of high nibble

        return string(next_n(self, n));
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

        map = EncodedMap(new string[](n), new bytes[](n));

        for (uint256 i = 0; i < n; i++) {
            map.keys[i] = deser_fixstr(self);
            map.values[i] = deser_encode(self);
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

        map = EncodedMap(new string[](n), new bytes[](n));

        for (uint16 i = 0; i < n; i++) {
            map.keys[i] = deser_fixstr(self);
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

    function deser_posfixint(Stream memory self) public view returns (uint256) {
        bytes1 first = next(self);
        require(first >> 7 == 0x00, "not a positive fixint");

        return uint256(uint8(first));
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

    function deser_verifier_index(
        Stream memory self,
        VerifierIndex storage index
    ) public {
        EncodedMap memory map = deser_map16(self);
        index.max_poly_size = abi.decode(
            find_value(map, "max_poly_size"),
            (uint256)
        );
        index.public_len = abi.decode(
            find_value(map, "public"),
            (uint256)
        );
    }

    function find_value(EncodedMap memory self, string memory key)
        public
        returns (bytes memory)
    {
        uint256 i = 0;
        while (keccak256(bytes(self.keys[i])) != keccak256(bytes(key))) i++;
        return self.values[i];
    }

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
