// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import "../bn254/BN254.sol";
import "../Commitment.sol";
import "../Proof.sol";
import "../Constants.sol";

library KeccakSponge {
    using {BN254.isInfinity} for BN254.G1Point;

    struct Sponge {
        bytes pending;
    }

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

    function absorb_scalar(Sponge storage self, Scalar.FE elem) public {
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

    function absorb_evaluations(
        Sponge storage self,
        Proof.ProofEvaluations memory evals
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

        if (Proof.is_field_set(evals.optional_field_flags, RANGE_CHECK0_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.range_check0_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, RANGE_CHECK1_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.range_check1_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, FOREIGN_FIELD_ADD_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.foreign_field_add_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, FOREIGN_FIELD_MUL_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.foreign_field_mul_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, XOR_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.xor_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, ROT_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.rot_selector);
        }

        if (Proof.is_field_set(evals.optional_field_flags, LOOKUP_AGGREGATION_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.lookup_aggregation);
        }
        if (Proof.is_field_set(evals.optional_field_flags, LOOKUP_TABLE_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.lookup_table);
        }
        for (uint i = 0; i < evals.lookup_sorted.length; i++) {
            if (Proof.is_field_set(evals.optional_field_flags, LOOKUP_SORTED_EVAL_FLAG + i)) {
                absorb_point_evaluation(self, evals.lookup_sorted[i]);
            }
        }
        if (Proof.is_field_set(evals.optional_field_flags, RUNTIME_LOOKUP_TABLE_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.runtime_lookup_table);
        }

        if (Proof.is_field_set(evals.optional_field_flags, RUNTIME_LOOKUP_TABLE_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.runtime_lookup_table_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, XOR_LOOKUP_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.xor_lookup_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, LOOKUP_GATE_LOOKUP_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.lookup_gate_lookup_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, RANGE_CHECK_LOOKUP_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.range_check_lookup_selector);
        }
        if (Proof.is_field_set(evals.optional_field_flags, FOREIGN_FIELD_MUL_LOOKUP_SELECTOR_EVAL_FLAG)) {
            absorb_point_evaluation(self, evals.foreign_field_mul_lookup_selector);
        }
    }

    function absorb_point_evaluation(
        Sponge storage self,
        PointEvaluations memory eval
    ) public {
        absorb_scalar(self, eval.zeta);
        absorb_scalar(self, eval.zeta_omega);
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

    function mds() external pure returns (Scalar.FE[3][3] memory) {
        return [
            [
                Scalar.from(12035446894107573964500871153637039653510326950134440362813193268448863222019),
                Scalar.from(25461374787957152039031444204194007219326765802730624564074257060397341542093),
                Scalar.from(27667907157110496066452777015908813333407980290333709698851344970789663080149)
            ],
            [
                Scalar.from(4491931056866994439025447213644536587424785196363427220456343191847333476930),
                Scalar.from(14743631939509747387607291926699970421064627808101543132147270746750887019919),
                Scalar.from(9448400033389617131295304336481030167723486090288313334230651810071857784477)
            ],
            [
                Scalar.from(10525578725509990281643336361904863911009900817790387635342941550657754064843),
                Scalar.from(27437632000253211280915908546961303399777448677029255413769125486614773776695),
                Scalar.from(27566319851776897085443681456689352477426926500749993803132851225169606086988)
            ]
        ];
    }
}
