// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../Proof.sol";
import "../bn254/BN254.sol";

/// @notice demonstrates the "deserialization" of incoming PairingProof data.
function deser_pairing_proof(bytes memory, PairingProof storage pairing_proof) {
    assembly {
        let offset := 0xa0 // memory starts at 0x80,
            // first 32 bytes is the length of the bytes array.
        let slot := pairing_proof.slot

        sstore(add(slot, 0), mload(add(offset, 0x00)))
        sstore(add(slot, 1), mload(add(offset, 0x20)))
        sstore(add(slot, 2), mload(add(offset, 0x40)))
    }
}
