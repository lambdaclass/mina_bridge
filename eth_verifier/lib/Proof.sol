// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";

struct ProverProof {
    ProofEvaluations evals;
}

struct ProofEvaluations {
    PointEvaluationsArray public_evals;
    bool is_public_evals_set; // public_evals is optional
}
