// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Kimchi} from "../../src/Verifier.sol";
import "../Commitment.sol";
import "../BN254.sol";
import "../Evaluations.sol";
import "../Proof.sol";

library MsgPk {
    struct Stream {
        bytes data;
        uint curr_index;
    }

    struct EncodedArray {
        bytes[] values;
    }

    struct EncodedMap {
        string[] keys;
        bytes[] values;
    }

    function from_data(bytes calldata data) public pure returns (Stream memory) {
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

    function next_n(
        Stream memory self,
        uint n
    ) public pure returns (bytes memory consumed) {
        consumed = new bytes(n);
        for (uint i = 1; i <= n; i++) {
            consumed[i] = self.data[self.curr_index + i];
        }
        self.curr_index += n;
    }

    error NonImplementedType();
    /// @notice deserializes the next type and returns the encoded data.
    function trim_encode(Stream memory self) public pure returns (bytes memory) {
        bytes1 prefix = curr(self);
        if (prefix >> 5 == 0x05) {
            return abi.encode(deser_fixstr(self));
        } else if (prefix >> 4 == 0x08) {
            return abi.encode(deser_fixmap(self));
        } else {
            revert NonImplementedType();
        }
    }

    function deser_fixstr(Stream memory self) public pure returns (string memory) {
        bytes1 first = next(self);
        require(first >> 5 == 0x05, "not a fixstr");
        uint n = uint256(uint8(first & 0x1F)); // low nibble + lsb of high nibble

        return string(next_n(self, n));
    }

    function deser_fixarr(Stream memory self) public pure returns (EncodedArray memory arr) {
        bytes1 first = next(self);
        require(first >> 4 == 0x09, "not a fixarr");
        uint n = uint256(uint8(first & 0x0F)); // low nibble

        arr = EncodedArray(new bytes[](n));

        for (uint i = 0; i < n; i++) {
            arr.values[i] = trim_encode(self);
        }
    }

    function deser_fixmap(Stream memory self) public pure returns (EncodedMap memory map) {
        bytes1 first = next(self);
        require(first >> 4 == 0x08, "not a fixmap");
        uint n = uint256(uint8(first & 0x0F)); // low nibble

        map = EncodedMap(new string[](n), new bytes[](n));

        for (uint i = 0; i < n; i++) {
            map.keys[i] = deser_fixstr(self);
            map.values[i] = trim_encode(self);
        }
    }

    /// @notice deserializes an array of G1Point and also returns the rest of the
    // data, excluding the consumed bytes. `i` is the index that we start to read
    // the data from.
    function deserializeG1Point(
        bytes calldata data,
        uint256 i
    ) public view returns (BN254.G1Point memory p, uint256 final_i) {
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
    function deserializeURS(
        bytes calldata data
    )
        public
        view
        returns (BN254.G1Point[] memory, BN254.G1Point memory, uint256)
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

    function deserializeOpeningProof(
        bytes calldata serialized_proof
    ) public view returns (Kimchi.ProverProof memory proof) {
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

    function deserializeScalar(
        bytes calldata data,
        uint256 i
    ) public pure returns (Scalar.FE scalar, uint256 final_i) {
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

    function deserializePointEvals(
        bytes calldata data,
        uint256 i
    ) public pure returns (PointEvaluations memory eval, uint256 final_i) {
        require(data[i] == 0x92, "not a fix array of two elements");
        i += 1;
        require(data[i] == 0x91, "not a fix array of one element");
        i += 1;

        (Scalar.FE zeta, uint i0) = deserializeScalar(data, i);
        i = i0;
        require(data[i] == 0x91, "not a fix array of one element");
        i += 1;
        (Scalar.FE zeta_omega, uint i1) = deserializeScalar(data, i);
        i = i1;

        eval = PointEvaluations(zeta, zeta_omega);
        final_i = i;
    }

    function deserializeProofEvaluations(
        bytes calldata data,
        uint256 i
    ) public pure returns (ProofEvaluations memory evals, uint256 final_i) {
        // WARN: This works because the test circuit evaluations have one elem per array.
        (
            PointEvaluations memory evals_non_array,
            uint _i
        ) = deserializePointEvals(data, i);

        Scalar.FE[] memory zeta = new Scalar.FE[](1);
        Scalar.FE[] memory zeta_omega = new Scalar.FE[](1);
        zeta[0] = evals_non_array.zeta;
        zeta_omega[0] = evals_non_array.zeta_omega;

        PointEvaluationsArray memory _public_evals = PointEvaluationsArray(
            zeta,
            zeta_omega
        );

        // array needed to simulate an optional param
        PointEvaluationsArray[]
            memory public_evals = new PointEvaluationsArray[](1);
        public_evals[0] = _public_evals;
        evals = ProofEvaluations(public_evals);
        final_i = _i;
    }
}
