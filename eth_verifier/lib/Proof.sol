// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import "./expr/Expr.sol";

struct ProverProof {
    ProofEvaluationsArray evals;
}

struct ProofEvaluations {
    // public inputs polynomials
    PointEvaluations public_evals;
    bool is_public_evals_set; // public_evals is optional

    // witness polynomials
    PointEvaluations[15] w; // TODO: use Constants.COLUMNS

    // permutation polynomial
    PointEvaluations z;

    // permutation polynomials
    // (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
    PointEvaluations[7 - 1] s; // TODO: use Constants.PERMUTS
}

struct ProofEvaluationsArray {
    PointEvaluationsArray public_evals;
    bool is_public_evals_set; // public_evals is optional

    // witness polynomials
    PointEvaluationsArray[15] w; // TODO: use Constants.COLUMNS

    // permutation polynomial
    PointEvaluationsArray z;

    // permutation polynomials
    // (PERMUTS-1 evaluations because the last permutation is only used in commitment form)
    PointEvaluationsArray[7 - 1] s; // TODO: use Constants.PERMUTS
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

    PointEvaluations[15] memory w;
    for (uint i = 0; i < 15; i++) {
        w[i] = PointEvaluations(
            Polynomial.build_and_eval(self.w[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.w[i].zeta_omega, pt.zeta_omega)
        );
    }

    PointEvaluations memory z;
        z = PointEvaluations(
            Polynomial.build_and_eval(self.z.zeta, pt.zeta),
            Polynomial.build_and_eval(self.z.zeta_omega, pt.zeta_omega)
        );

    PointEvaluations[7 - 1] memory s;
    for (uint i = 0; i < 7 - 1; i++) {
        s[i] = PointEvaluations(
            Polynomial.build_and_eval(self.s[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.s[i].zeta_omega, pt.zeta_omega)
        );
    }

    return ProofEvaluations(public_evals, self.is_public_evals_set, w, z, s);
}

function evaluate_column(ProofEvaluations memory self, Column )

function evaluate_variable(
    Variable memory self,
    ProofEvaluations memory evals
) pure returns (Scalar.FE) {

}

