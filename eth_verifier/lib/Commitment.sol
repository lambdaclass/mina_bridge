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

// @notice Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
// @notice If empty, returns a commitment with the point at infinity.
function polycomm_msm(PolyComm[] memory com, Scalar.FE[] memory elm) view returns (PolyComm memory) {
    if (com.length == 0 || elm.length == 0) {
        BN254.G1Point[] memory z = new BN254.G1Point[](1);
        z[0] = BN254.point_at_inf();
        // TODO: shifted is fixed to infinity
        BN254.G1Point memory shifted = BN254.point_at_inf();
        return PolyComm(z, shifted);
    }

    if (com.length != elm.length) {
        revert MSMInvalidLengths();
    }
    uint256 n = com.length;

    uint256 unshifted_len = 0;
    // INFO: can use unchecked on for loops to save gas
    for (uint256 i = 0; i < com.length; i++) {
        uint256 len = com[i].unshifted.length;
        if (unshifted_len < len) {
            unshifted_len = len;
        }
    }

    BN254.G1Point[] memory unshifted = new BN254.G1Point[](unshifted_len);
    uint256 chunk = 0;
    while (chunk < unshifted_len) {
        // zip with elements and filter scalars that don't have an associated chunk.

        // first get the count of elements that have a chunk:
        uint256 chunk_length = 0;
        uint256 i1 = 0;
        while (i1 < n) {
            if (com[i1].unshifted.length > chunk) {
                chunk_length++;
            }
            ++i1;
        }

        // fill arrays
        BN254.G1Point[] memory points = new BN254.G1Point[](chunk_length);
        Scalar.FE[] memory scalars = new Scalar.FE[](chunk_length);
        uint256 index = 0;
        uint256 i2 = 0;
        while (i2 < n) {
            if (com[i2].unshifted.length > chunk) {
                points[index] = (com[i2].unshifted[chunk]);
                scalars[index] = (elm[i2]);
                index++;
            }
            ++i2;
        }

        BN254.G1Point memory chunk_msm = msm(points, scalars);
        unshifted[chunk] = chunk_msm;
        ++chunk;
    }
    // TODO: shifted is fixed to infinity
    BN254.G1Point memory shifted = BN254.point_at_inf();
    return PolyComm(unshifted, shifted);
}

// @notice Execute a simple multi-scalar multiplication with points on G1
function msm(BN254.G1Point[] memory points, Scalar.FE[] memory scalars) view returns (BN254.G1Point memory result) {
    uint256[] memory scalars_uint = new uint256[](points.length);
    uint256 i = points.length;
    while (i > 0) {
        --i;
        scalars_uint[i] = Scalar.FE.unwrap(scalars[i]);
    }
    result = BN254.multiScalarMul(points, scalars_uint);
}

// @notice Execute a simple multi-scalar multiplication with points on G2
function naive_msm(BN254.G2Point[] memory points, Scalar.FE[] memory scalars) view returns (BN254.G2Point memory) {
    BN254.G2Point memory result = BN254.point_at_inf_g2();

    for (uint256 i = 0; i < points.length; i++) {
        BN254.G2Point memory p = BN256G2.ECTwistMul(Scalar.FE.unwrap(scalars[i]), points[i]);
        result = BN256G2.ECTwistAdd(result, p);
    }

    return result;
}

// @notice substracts two polynomial commitments
function sub_polycomms(PolyComm memory self, PolyComm memory other) view returns (PolyComm memory res) {
    uint256 n_self = self.unshifted.length;
    uint256 n_other = other.unshifted.length;
    uint256 n = Utils.max(n_self, n_other);
    res.unshifted = new BN254.G1Point[](n);

    for (uint256 i = 0; i < n; i++) {
        if (i < n_self && i < n_other) {
            res.unshifted[i] = self.unshifted[i].add(other.unshifted[i].neg());
        } else if (i < n_self) {
            res.unshifted[i] = self.unshifted[i];
        } else {
            res.unshifted[i] = other.unshifted[i];
        }
    }
    // TODO: shifted part, need to create a flag that determines if shifted is set.
}

// @notice substracts two polynomial commitments
function scale_polycomm(PolyComm memory self, Scalar.FE c) view returns (PolyComm memory res) {
    uint256 n = self.unshifted.length;
    res.unshifted = new BN254.G1Point[](n);

    for (uint256 i = 0; i < n; i++) {
        res.unshifted[i] = self.unshifted[i].scale_scalar(c);
    }
    // TODO: shifted part, need to create a flag that determines if shifted is set.
}

function combine_commitments_and_evaluations(Evaluation[] memory evaluations, Scalar.FE polyscale, Scalar.FE rand_base)
    view
    returns (BN254.G1Point memory poly_commitment, Scalar.FE[] memory acc)
{
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
