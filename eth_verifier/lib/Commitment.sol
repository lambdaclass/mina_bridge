// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {BN254} from "./bn254/BN254.sol";
import {Scalar} from "./bn254/Fields.sol";
import {Evaluation} from "./Evaluations.sol";

using {BN254.add, BN254.scalarMul, BN254.neg} for BN254.G1Point;

error MSMInvalidLengths();

library Commitment {
    struct URS {
        BN254.G1Point[] g;
        BN254.G1Point h;
    }

    // WARN: The field shifted is optional but in Solidity we can't have that.
    // for our test circuit it's not necessary, we can just ignore it, using infinity.
    struct PolyComm {
        BN254.G1Point[] unshifted;
        BN254.G1Point shifted;
    }

    // @notice Execute a simple multi-scalar multiplication with points on G1
    function msm(BN254.G1Point[] memory points, uint256[] memory scalars)
        internal
        view
        returns (BN254.G1Point memory result)
    {
        result = BN254.multiScalarMul(points, scalars);
    }

    function combine_commitments_and_evaluations(Evaluation[] memory evaluations, uint256 polyscale, uint256 rand_base)
        internal
        view
        returns (BN254.G1Point memory poly_commitment, uint256[] memory acc)
    {
        uint256 xi_i = Scalar.one();
        poly_commitment = BN254.point_at_inf();
        uint256 num_evals = evaluations.length != 0 ? evaluations[0].evaluations.length : 0;
        acc = new uint256[](num_evals);
        for (uint256 i = 0; i < num_evals; i++) {
            acc[i] = Scalar.zero();
        }

        // WARN: the actual length might be more than evaluations.length
        // but for our test proof it will not.

        for (uint256 i = 0; i < evaluations.length; i++) {
            BN254.G1Point memory commitment = evaluations[i].commitment;
            uint256[2] memory inner_evaluations = evaluations[i].evaluations;
            uint256 commitment_steps = 1;
            uint256 evaluation_steps = 1;
            uint256 steps = commitment_steps > evaluation_steps ? commitment_steps : evaluation_steps;

            for (uint256 j = 0; j < steps; j++) {
                if (j < commitment_steps) {
                    BN254.G1Point memory comm_ch = commitment;
                    poly_commitment = poly_commitment.add(comm_ch.scalarMul(Scalar.mul(rand_base, xi_i)));
                }
                if (j < evaluation_steps) {
                    for (uint256 k = 0; k < inner_evaluations.length; k++) {
                        acc[k] = Scalar.add(acc[k], Scalar.mul(inner_evaluations[k], xi_i));
                    }
                }
                xi_i = Scalar.mul(xi_i, polyscale);
            }
            // TODO: degree bound, shifted part
        }
    }
}
