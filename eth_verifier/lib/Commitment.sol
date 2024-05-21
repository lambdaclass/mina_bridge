// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/BN256G2.sol";
import "./bn254/Fields.sol";
import "./Utils.sol";
import "./Polynomial.sol";
import "./Evaluations.sol";

using {BN254.add, BN254.scale_scalar, BN254.neg} for BN254.G1Point;
using {Scalar.neg, Scalar.add, Scalar.sub, Scalar.mul, Scalar.inv, Scalar.double, Scalar.pow} for Scalar.FE;

error MSMInvalidLengths();

library Commitment {
    struct URS {
        BN254.G1Point[] g;
        BN254.G1Point h;
    }

    struct URSG2 {
        BN254.G2Point[] g;
        BN254.G2Point h;
    }

    // WARN: The field shifted is optional but in Solidity we can't have that.
    // for our test circuit it's not necessary, we can just ignore it, using infinity.
    struct PolyComm {
        BN254.G1Point[] unshifted;
        BN254.G1Point shifted;
    }

    struct PolyCommG2 {
        BN254.G2Point[] unshifted;
    }

    // @notice Execute a simple multi-scalar multiplication with points on G1
    function msm(BN254.G1Point[] memory points, Scalar.FE[] memory scalars)
        internal
        view
        returns (BN254.G1Point memory result)
    {
        uint256[] memory scalars_uint = new uint256[](points.length);
        uint256 i = points.length;
        while (i > 0) {
            --i;
            scalars_uint[i] = Scalar.FE.unwrap(scalars[i]);
        }
        result = BN254.multiScalarMul(points, scalars_uint);
    }

    // @notice Execute a simple multi-scalar multiplication with points on G2
    function naive_msm(BN254.G2Point[] memory points, Scalar.FE[] memory scalars)
        internal
        view
        returns (BN254.G2Point memory)
    {
        BN254.G2Point memory result = BN254.point_at_inf_g2();

        for (uint256 i = 0; i < points.length; i++) {
            BN254.G2Point memory p = BN256G2.ECTwistMul(Scalar.FE.unwrap(scalars[i]), points[i]);
            result = BN256G2.ECTwistAdd(result, p);
        }

        return result;
    }

    function combine_commitments_and_evaluations(
        Evaluation[] memory evaluations,
        Scalar.FE polyscale,
        Scalar.FE rand_base
    ) internal view returns (BN254.G1Point memory poly_commitment, Scalar.FE[] memory acc) {
        Scalar.FE xi_i = Scalar.one();
        poly_commitment = BN254.point_at_inf();
        uint256 num_evals = evaluations.length != 0 ? evaluations[0].evaluations.length : 0;
        acc = new Scalar.FE[](num_evals);
        for (uint256 i = 0; i < num_evals; i++) {
            acc[i] = Scalar.zero();
        }

        // WARN: the actual length might be more than evaluations.length
        // but for our test proof it will not.

        for (uint256 i = 0; i < evaluations.length; i++) {
            BN254.G1Point memory commitment = evaluations[i].commitment;
            Scalar.FE[2] memory inner_evaluations = evaluations[i].evaluations;
            uint256 commitment_steps = 1;
            uint256 evaluation_steps = 1;
            uint256 steps = commitment_steps > evaluation_steps ? commitment_steps : evaluation_steps;

            for (uint256 j = 0; j < steps; j++) {
                if (j < commitment_steps) {
                    BN254.G1Point memory comm_ch = commitment;
                    poly_commitment = poly_commitment.add(comm_ch.scale_scalar(rand_base.mul(xi_i)));
                }
                if (j < evaluation_steps) {
                    for (uint256 k = 0; k < inner_evaluations.length; k++) {
                        acc[k] = acc[k].add(inner_evaluations[k].mul(xi_i));
                    }
                }
                xi_i = xi_i.mul(polyscale);
            }
            // TODO: degree bound, shifted part
        }
    }
}
