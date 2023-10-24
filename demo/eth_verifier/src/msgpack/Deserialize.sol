// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Verifier.sol";
import "../BN254.sol";

library MsgPk {
    function deserializeOpeningProof(bytes calldata serialized_proof)
        public
        view
        returns (Kimchi.ProverProof memory proof)
    {
        uint256 i = 0;
        bytes1 firstbyte = serialized_proof[i];
        // first byte is 0x92, indicating this is a map with 2 elements
        require(firstbyte == 0x92, "first byte is not 0x92");

        // read lenght of the data
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
