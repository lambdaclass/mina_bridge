// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Scalar} from "./bn254/Fields.sol";
import {BN254} from "./bn254/BN254.sol";

struct PointEvaluations {
    /// evaluation at the challenge point zeta
    Scalar.FE zeta;
    /// Evaluation at `zeta . omega`, the product of the challenge point and the group generator
    Scalar.FE zeta_omega;
}

struct PointEvaluationsArray {
    /// evaluation at the challenge point zeta
    Scalar.FE[] zeta;
    /// Evaluation at `zeta . omega`, the product of the challenge point and the group generator
    Scalar.FE[] zeta_omega;
}

/// Contains the evaluation of a polynomial commitment at a set of points.
struct Evaluation {
    /// The commitment of the polynomial being evaluated
    BN254.G1Point commitment; // TODO: Dense
    /// Contains an evaluation table
    Scalar.FE[2] evaluations;
    /// optional degree bound
    uint128 degree_bound;
}
