// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Evaluations.sol";

struct ProverProof {
    ProofEvaluations evals;
}

struct ProofEvaluations {
    // array of length 1 serves as optional field
    PointEvaluationsArray[] public_evals;
}
