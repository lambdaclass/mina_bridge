// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import "../bn254/BN254.sol";
import "../Commitment.sol";
import "../Proof.sol";

struct Sponge {
    bytes pending;
}

using {BN254.isInfinity} for BN254.G1Point;

library KeccakSponge {
    // Basic methods

    function reinit(Sponge storage self) external {
        self.pending = new bytes(0);
    }

    function absorb(Sponge storage self, bytes memory b) external {
        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push(b[i]);
        }
    }

    function squeeze(Sponge memory self, uint256 byte_count)
        public
        pure
        returns (bytes memory digest)
    {
        digest = new bytes(byte_count);

        uint counter = 0;
        while (counter < byte_count) {
            bytes32 output = keccak256(self.pending);

            for (uint i = 0; i < 32; i++) {
                counter++;
                if (counter >= byte_count) {
                    break;
                }
                digest[counter] = output[i];
            }

            // pending <- output
            for (uint i = 0; i < 32; i++) {
                self.pending[i] = output[i];
            }
        }
    }

    // KZG methods

    function absorb_base(Sponge storage self, Base.FE elem) public {
        bytes memory b = abi.encodePacked(elem);
        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push(b[i]);
        }
    }

    function absorb_scalar(Sponge storage self, Scalar.FE elem) external {
        bytes memory b = abi.encodePacked(elem);
        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push(b[i]);
        }
    }

    function absorb_scalar_multiple(
        Sponge storage self,
        Scalar.FE[] memory elems
    ) external {
        bytes memory b = abi.encodePacked(elems);
        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push(b[i]);
        }
    }

    function absorb_g(Sponge storage self, BN254.G1Point[] memory points)
        public
    {
        for (uint256 i = 0; i < points.length; i++) {
            BN254.G1Point memory point = points[i];
            if (point.isInfinity()) {
                absorb_base(self, Base.zero());
                absorb_base(self, Base.zero());
            } else {
                absorb_base(self, Base.from(point.x));
                absorb_base(self, Base.from(point.y));
            }
        }
    }

    function absorb_commitment(Sponge storage self, PolyComm memory comm)
        external
    {
        absorb_g(self, comm.unshifted);
        if (!comm.shifted.isInfinity()) {
            BN254.G1Point[] memory shifted = new BN254.G1Point[](1);
            shifted[0] = comm.shifted;
            absorb_g(self, shifted);
        }
        // WARN: we should keep in mind that if the shifted part is assigned
        // to the point at infinity then it means that there's no shifted part.
    }

    function absorb_evaluations(
        Sponge storage self,
        ProofEvaluationsArray memory evals
    ) external {
        bytes[] memory b = new bytes[](1);
        b[0] = evals.is_public_evals_set
            ? abi.encode(evals.public_evals)
            : abi.encode(0);

        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push((b[0])[i]);
        }
    }

    function challenge_base(Sponge storage self)
        external
        pure
        returns (Base.FE chal)
    {
        chal = Base.from_bytes_be(squeeze(self, 16));
    }

    function challenge_scalar(Sponge storage self)
        external
        pure
        returns (Scalar.FE chal)
    {
        chal = Scalar.from_bytes_be(squeeze(self, 16));
    }

    function digest_base(Sponge storage self)
        external
        pure
        returns (Base.FE digest)
    {
        digest = Base.from_bytes_be(squeeze(self, 32));
    }

    function digest_scalar(Sponge storage self)
        external
        pure
        returns (Scalar.FE digest)
    {
        digest = Scalar.from_bytes_be(squeeze(self, 32));
    }
}
