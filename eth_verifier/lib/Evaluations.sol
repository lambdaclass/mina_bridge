// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/Fields.sol";
import "./Polynomial.sol";
import "./Commitment.sol";

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
    PolyComm commitment;
    /// Contains an evaluation table
    Scalar.FE[][] evaluations;
    /// optional degree bound
    uint128 degree_bound;
}
