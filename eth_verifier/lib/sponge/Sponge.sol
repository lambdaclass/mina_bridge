// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {BN254} from "../bn254/BN254.sol";
import {Scalar, Base} from "../bn254/Fields.sol";
import {Proof} from "../Proof.sol";
import {PointEvaluations, PointEvaluationsArray} from "../Evaluations.sol";
import {
    RANGE_CHECK0_SELECTOR_EVAL_FLAG,
    RANGE_CHECK1_SELECTOR_EVAL_FLAG,
    FOREIGN_FIELD_ADD_SELECTOR_EVAL_FLAG,
    FOREIGN_FIELD_MUL_SELECTOR_EVAL_FLAG,
    XOR_SELECTOR_EVAL_FLAG,
    ROT_SELECTOR_EVAL_FLAG,
    LOOKUP_AGGREGATION_EVAL_FLAG,
    LOOKUP_TABLE_EVAL_FLAG,
    LOOKUP_SORTED_EVAL_FLAG,
    RUNTIME_LOOKUP_TABLE_EVAL_FLAG,
    RUNTIME_LOOKUP_TABLE_SELECTOR_EVAL_FLAG,
    XOR_LOOKUP_SELECTOR_EVAL_FLAG,
    LOOKUP_GATE_LOOKUP_SELECTOR_EVAL_FLAG,
    RANGE_CHECK_LOOKUP_SELECTOR_EVAL_FLAG,
    FOREIGN_FIELD_MUL_LOOKUP_SELECTOR_EVAL_FLAG,
    MAX_SPONGE_STATE_SIZE
} from "../Constants.sol";

error SizeExceeded(); // max sponge state size exceeded

library KeccakSponge {
    using {BN254.isInfinity} for BN254.G1Point;

    struct Sponge {
        bytes pending;
        uint256 last_index;
    }

    // Basic methods
    function reinit(Sponge memory self) internal pure {
        self.pending = new bytes(MAX_SPONGE_STATE_SIZE);
        self.last_index = 0;
    }

    function absorb(Sponge memory self, bytes memory b) internal pure {
        for (uint256 i = 0; i < b.length; i++) {
            if (self.last_index >= MAX_SPONGE_STATE_SIZE) {
                revert SizeExceeded();
            }
            self.pending[self.last_index] = b[i];
            self.last_index += 1;
        }
    }

    function squeeze(Sponge memory self, uint256 byte_count) internal pure returns (bytes memory digest) {
        digest = new bytes(byte_count);
        bytes memory pending = new bytes(self.last_index);
        for (uint256 i = 0; i < pending.length; i++) {
            pending[i] = self.pending[i];
        }
        bytes32 output = keccak256(pending);

        for (uint256 i = 0; i < byte_count - 1; i++) {
            digest[i + 1] = output[i];
        }

        // pending <- output
        reinit(self);
        for (uint256 i = 0; i < 32; i++) {
            self.pending[i] = output[i];
        }
        self.last_index = 32;
    }

    // KZG methods

    function absorb_scalar(Sponge memory self, uint256 elem) internal pure {
        if ((self.last_index + 32) >= MAX_SPONGE_STATE_SIZE) {
            revert SizeExceeded();
        }

        bytes memory b = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(b, 32), elem)
        }

        for (uint256 i = 0; i < 32; i++) {
            self.pending[self.last_index + i] = b[i];
        }
        self.last_index += 32;
    }

    function absorb_g_single(Sponge memory self, BN254.G1Point memory point) internal pure {
        if (point.isInfinity()) {
            absorb_scalar(self, 0);
            absorb_scalar(self, 0);
        } else {
            absorb_scalar(self, point.x);
            absorb_scalar(self, point.y);
        }
    }

    function absorb_g(Sponge memory self, BN254.G1Point[] memory points) internal pure {
        for (uint256 i = 0; i < points.length; i++) {
            BN254.G1Point memory point = points[i];
            if (point.isInfinity()) {
                absorb_scalar(self, 0);
                absorb_scalar(self, 0);
            } else {
                absorb_scalar(self, point.x);
                absorb_scalar(self, point.y);
            }
        }
    }

    function absorb_evaluations(Sponge memory self, Proof.ProofEvaluations memory evals) internal pure {
        absorb_point_evaluation(self, evals.z);
        absorb_point_evaluation(self, evals.generic_selector);
        absorb_point_evaluation(self, evals.poseidon_selector);
        absorb_point_evaluation(self, evals.complete_add_selector);
        absorb_point_evaluation(self, evals.mul_selector);
        absorb_point_evaluation(self, evals.emul_selector);
        absorb_point_evaluation(self, evals.endomul_scalar_selector);

        for (uint256 i = 0; i < evals.w.length; i++) {
            absorb_point_evaluation(self, evals.w[i]);
        }
        for (uint256 i = 0; i < evals.coefficients.length; i++) {
            absorb_point_evaluation(self, evals.coefficients[i]);
        }
        for (uint256 i = 0; i < evals.s.length; i++) {
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
        for (uint256 i = 0; i < evals.lookup_sorted.length; i++) {
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

    function absorb_point_evaluation(Sponge memory self, PointEvaluations memory eval) internal pure {
        absorb_scalar(self, eval.zeta);
        absorb_scalar(self, eval.zeta_omega);
    }

    function challenge_base(Sponge memory self) internal pure returns (uint256 chal) {
        chal = Base.from_bytes_be(squeeze(self, 16));
    }

    function challenge_scalar(Sponge memory self) internal pure returns (uint256 chal) {
        chal = Scalar.from_bytes_be(squeeze(self, 16));
    }

    function digest_base(Sponge memory self) internal pure returns (uint256 digest) {
        digest = Base.from_bytes_be(squeeze(self, 32));
    }

    function digest_scalar(Sponge memory self) internal pure returns (uint256 digest) {
        digest = Scalar.from_bytes_be(squeeze(self, 32));
    }

    function mds() internal pure returns (uint256[3][3] memory) {
        return [
            [
                12035446894107573964500871153637039653510326950134440362813193268448863222019,
                25461374787957152039031444204194007219326765802730624564074257060397341542093,
                27667907157110496066452777015908813333407980290333709698851344970789663080149
            ],
            [
                4491931056866994439025447213644536587424785196363427220456343191847333476930,
                14743631939509747387607291926699970421064627808101543132147270746750887019919,
                9448400033389617131295304336481030167723486090288313334230651810071857784477
            ],
            [
                10525578725509990281643336361904863911009900817790387635342941550657754064843,
                27437632000253211280915908546961303399777448677029255413769125486614773776695,
                27566319851776897085443681456689352477426926500749993803132851225169606086988
            ]
        ];
    }
}
