// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";

struct ProverProof {
    ProofEvaluationsArray evals;
}

struct ProofEvaluations {
    PointEvaluations public_evals;
    bool is_public_evals_set; // public_evals is optional
}

struct ProofEvaluationsArray {
    PointEvaluationsArray public_evals;
    bool is_public_evals_set; // public_evals is optional
}

function combine_evals(
    ProofEvaluationsArray memory self,
    PointEvaluations memory pt
) pure returns (ProofEvaluations memory) {
    PointEvaluations memory public_evals;
    if (self.is_public_evals_set) {
        public_evals = PointEvaluations(
            Polynomial.build_and_eval(self.public_evals.zeta, pt.zeta),
            Polynomial.build_and_eval(
                self.public_evals.zeta_omega,
                pt.zeta_omega
            )
        );
    } else {
        public_evals = PointEvaluations(Scalar.zero(), Scalar.zero());
    }

    return ProofEvaluations(public_evals, self.is_public_evals_set);
}
