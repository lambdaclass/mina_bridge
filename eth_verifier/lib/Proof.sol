// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";
import "./Polynomial.sol";
import "./Constants.sol";
import "./expr/Expr.sol";

struct ProverProof {
    ProofEvaluationsArray evals;
    ProverCommitments commitments;
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

struct ProverCOmmitments {
    PolyComm[15] w_comm; // TODO: use Constants.COLUMNS
    PolyComm z_comm;
    PolyComm t_comm;
    // TODO: lookup commitments
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
    for (uint256 i = 0; i < 15; i++) {
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
    for (uint256 i = 0; i < 7 - 1; i++) {
        s[i] = PointEvaluations(
            Polynomial.build_and_eval(self.s[i].zeta, pt.zeta),
            Polynomial.build_and_eval(self.s[i].zeta_omega, pt.zeta_omega)
        );
    }

    return ProofEvaluations(public_evals, self.is_public_evals_set, w, z, s);
}

function evaluate_column(ProofEvaluations memory self, Column memory col)
    pure
    returns (PointEvaluations memory)
{
    if (col.variant == ColumnVariant.Witness) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.w[i];
    }
    if (col.variant == ColumnVariant.Z) {
        return self.z;
    }
    if (col.variant == ColumnVariant.Permutation) {
        uint256 i = abi.decode(col.data, (uint256));
        return self.w[i];
    }
    revert("unhandled column variant");
    // TODO: rest of variants, for this it's necessary to expand ProofEvaluations
}

function evaluate_variable(Variable memory self, ProofEvaluations memory evals)
    pure
    returns (Scalar.FE)
{
    PointEvaluations memory point_evals = evaluate_column(evals, self.col);
    if (self.row == CurrOrNext.Curr) {
        return point_evals.zeta;
    }
    if (self.row == CurrOrNext.Next) {
        return point_evals.zeta_omega;
    }
}
