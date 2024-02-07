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

    function squeeze(Sponge storage self, uint256 byte_count)
        public
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
            self.pending = new bytes(32);
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
    ) public {
        bytes memory b = abi.encodePacked(elems);
        for (uint256 i = 0; i < b.length; i++) {
            self.pending.push(b[i]);
        }
    }

    function absorb_g_single(Sponge storage self, BN254.G1Point memory point)
        public
    {
        if (point.isInfinity()) {
            absorb_base(self, Base.zero());
            absorb_base(self, Base.zero());
        } else {
            absorb_base(self, Base.from(point.x));
            absorb_base(self, Base.from(point.y));
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
        absorb_point_evaluation(self, evals.z);
        absorb_point_evaluation(self, evals.generic_selector);
        absorb_point_evaluation(self, evals.poseidon_selector);
        absorb_point_evaluation(self, evals.complete_add_selector);
        absorb_point_evaluation(self, evals.mul_selector);
        absorb_point_evaluation(self, evals.emul_selector);
        absorb_point_evaluation(self, evals.endomul_scalar_selector);

        for (uint i = 0; i < evals.w.length; i++) {
            absorb_point_evaluation(self, evals.w[i]);
        }
        for (uint i = 0; i < evals.coefficients.length; i++) {
            absorb_point_evaluation(self, evals.coefficients[i]);
        }
        for (uint i = 0; i < evals.s.length; i++) {
            absorb_point_evaluation(self, evals.s[i]);
        }

        if (evals.is_range_check0_selector_set) {
            absorb_point_evaluation(self, evals.range_check0_selector);
        }
        if (evals.is_range_check1_selector_set) {
            absorb_point_evaluation(self, evals.range_check1_selector);
        }
        if (evals.is_foreign_field_add_selector_set) {
            absorb_point_evaluation(self, evals.foreign_field_add_selector);
        }
        if (evals.is_foreign_field_mul_selector_set) {
            absorb_point_evaluation(self, evals.foreign_field_mul_selector);
        }
        if (evals.is_xor_selector_set) {
            absorb_point_evaluation(self, evals.xor_selector);
        }
        if (evals.is_rot_selector_set) {
            absorb_point_evaluation(self, evals.rot_selector);
        }

        if (evals.is_lookup_aggregation_set) {
            absorb_point_evaluation(self, evals.lookup_aggregation);
        }
        if (evals.is_lookup_table_set) {
            absorb_point_evaluation(self, evals.lookup_table);
        }
        if (evals.is_lookup_sorted_set) {
            for (uint i = 0; i < evals.lookup_sorted.length; i++) {
                absorb_point_evaluation(self, evals.lookup_sorted[i]);
            }
        }
        if (evals.is_runtime_lookup_table_set) {
            absorb_point_evaluation(self, evals.runtime_lookup_table);
        }

        if (evals.is_runtime_lookup_table_selector_set) {
            absorb_point_evaluation(self, evals.runtime_lookup_table_selector);
        }
        if (evals.is_xor_lookup_selector_set) {
            absorb_point_evaluation(self, evals.xor_lookup_selector);
        }
        if (evals.is_lookup_gate_lookup_selector_set) {
            absorb_point_evaluation(self, evals.lookup_gate_lookup_selector);
        }
        if (evals.is_range_check_lookup_selector_set) {
            absorb_point_evaluation(self, evals.range_check_lookup_selector);
        }
        if (evals.is_foreign_field_mul_lookup_selector_set) {
            absorb_point_evaluation(self, evals.foreign_field_mul_lookup_selector);
        }
    }

    function absorb_point_evaluation(
        Sponge storage self,
        PointEvaluationsArray memory eval
    ) public {
        absorb_scalar_multiple(self, eval.zeta);
        absorb_scalar_multiple(self, eval.zeta_omega);
    }

    function absorb_point_evaluations(
        Sponge storage self,
        PointEvaluationsArray[] memory evals
    ) public {
        for (uint i; i < evals.length; i++) {
            absorb_scalar_multiple(self, evals[i].zeta);
            absorb_scalar_multiple(self, evals[i].zeta_omega);
        }
    }

    function challenge_base(Sponge storage self)
        external
        returns (Base.FE chal)
    {
        chal = Base.from_bytes_be(squeeze(self, 16));
    }

    function challenge_scalar(Sponge storage self)
        external
        returns (Scalar.FE chal)
    {
        chal = Scalar.from_bytes_be(squeeze(self, 16));
    }

    function digest_base(Sponge storage self)
        external
        returns (Base.FE digest)
    {
        digest = Base.from_bytes_be(squeeze(self, 32));
    }

    function digest_scalar(Sponge storage self)
        external
        returns (Scalar.FE digest)
    {
        digest = Scalar.from_bytes_be(squeeze(self, 32));
    }
}
