// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import "../bn254/BN254.sol";
import "../Commitment.sol";

struct Sponge {
    bytes state;
}

library KeccakSponge {
    // Basic methods

    function reinit(Sponge storage self) external {
        self.state = new bytes(0);
    }

    function absorb(Sponge storage self, bytes memory b) external {
        for (uint i = 0; i < b.length; i++) {
            self.state.push(b[i]);
        }
    }

    function squeeze(
        Sponge memory self,
        uint byte_count
    ) public pure returns (bytes memory digest) {
        digest = new bytes(byte_count);
        bytes32 output;

        for (uint i = 0; i < byte_count; i++) {
            if (i % 32 == 0) {
                output = keccak256(self.state);
                self.state = abi.encode(output);
            }

            digest[i] = output[i % 32];
        }
    }

    // KZG methods

    function absorb_base(Sponge storage self, Base.FE elem) external {
        bytes memory b = abi.encode(elem);
        for (uint i = 0; i < b.length; i++) {
            self.state.push(b[i]);
        }
    }

    function absorb_scalar(Sponge storage self, Scalar.FE elem) external {
        bytes memory b = abi.encode(elem);
        for (uint i = 0; i < b.length; i++) {
            self.state.push(b[i]);
        }
    }

    function absorb_g(
        Sponge storage self,
        BN254.G1Point memory point
    ) external {
        bytes memory b = abi.encode(point);
        for (uint i = 0; i < b.length; i++) {
            self.state.push(b[i]);
        }
    }

    function absorb_commitment(
        Sponge storage self,
        PolyComm memory comm
    ) external {
        bytes memory b = abi.encode(comm);
        for (uint i = 0; i < b.length; i++) {
            self.state.push(b[i]);
        }
    }

    function challenge_base(
        Sponge storage self
    ) external pure returns (Base.FE chal) {
        chal = Base.from_bytes_be(squeeze(self, 16));
    }

    function challenge_scalar(
        Sponge storage self
    ) external pure returns (Scalar.FE chal) {
        chal = Scalar.from_bytes_be(squeeze(self, 16));
    }

    function digest_base(
        Sponge storage self
    ) external pure returns (Base.FE digest) {
        digest = Base.from_bytes_be(squeeze(self, 32));
    }

    function digest_scalar(
        Sponge storage self
    ) external pure returns (Scalar.FE digest) {
        digest = Scalar.from_bytes_be(squeeze(self, 32));
    }
}
