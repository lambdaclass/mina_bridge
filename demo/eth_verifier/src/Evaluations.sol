// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./Fields.sol";

struct PointEvaluation {
    /// evaluation at the challenge point zeta
    Scalar.FE zeta;
    /// Evaluation at `zeta . omega`, the product of the challenge point and the group generator
    Scalar.FE zeta_omega;
}
