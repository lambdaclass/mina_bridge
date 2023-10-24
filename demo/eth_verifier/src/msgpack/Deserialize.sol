// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Verifier.sol";
import "../Commitment.sol";
import "../BN254.sol";

library MsgPk {
    /// @notice deserializes an array of G1Points (the second byte specifies the
    // size of the next data) and also returns the rest of the data, excluding the
    // consumed bytes.
    function deserializeG1PointArray(bytes calldata data, uint size)
        public
        view
        returns (BN254.G1Point[] memory arr, bytes memory rest_of_data)
    {
        uint i = 0;
        for (uint256 elem = 0; elem < size; elem++) {
            // read length of the data
            require(data[i] == 0xC4, "byte is not 0xC4");

            // next byte is the length of the data in one byte
            i += 1;
            require(data[i] == 0x20, "size of element is not 32 bytes");

            // read data
            i += 1;
            arr[elem] = BN254.g1Deserialize(
                abi.decode(data[i:i + 32], (bytes32))
            );

            i += 32;
        }
        rest_of_data = data[i:];
    }

    function deserializeURS(bytes calldata data) public view returns (URS storage) {
        uint256 i = 0;
        // first byte is 0x9X, indicating this is an array
        require(data[i] >> 4 == 0x09, "first byte is not 0x9X");

        (BN254.G1Point[] memory g, bytes memory data1) = deserializeG1PointArray(data[1:], 3);
        (BN254.G1Point[] memory h, bytes memory data2) = deserializeG1PointArray(data1, 1);
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
}
