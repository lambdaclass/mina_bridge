// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./BN254.sol";
using { BN254.add, BN254.scale_scalar } for BN254.G1Point;
import {Scalar} from "./Fields.sol";

error MSMInvalidLengths();

struct URS {
    BN254.G1Point[] g;
    BN254.G1Point h;
    mapping(uint256 => PolyComm[]) lagrange_bases;
}

struct PolyComm {
    BN254.G1Point[] unshifted;
    //BN254G1Point shifted;
    // WARN: The previous field is optional but in Solidity we can't have that.
    // for our test circuit (circuit_gen/) it's not necessary
}

// @notice Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
// @notice If empty, returns a commitment with the point at infinity.
function polycomm_msm(PolyComm[] memory com, Scalar.FE[] memory elm)
    view
    returns (PolyComm memory)
{
    if (com.length == 0 || elm.length == 0) {
        BN254.G1Point[] storage z;
        z.push(BN254.point_at_inf());
        return PolyComm(z);
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
    BN254.G1Point[] storage unshifted;

    for (uint256 chunk = 0; chunk < unshifted_len; chunk++) {
        BN254.G1Point[] storage points;
        Scalar.FE[] storage scalars;

        // zip with elements and filter scalars that don't have an associated chunk.
        for (uint256 i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                points.push(com[i].unshifted[chunk]);
                scalars.push(elm[i]);
            }
        }

        BN254.G1Point memory chunk_msm = naive_msm(points, scalars);
        unshifted.push(chunk_msm);
    }
    return PolyComm(unshifted);
}

// @notice Execute a simple multi-scalar multiplication
function naive_msm(BN254.G1Point[] memory points, Scalar.FE[] memory scalars)
    view
    returns (BN254.G1Point memory)
{
    BN254.G1Point memory result = BN254.point_at_inf();

    for (uint256 i = 0; i < points.length; i++) {
        result = result.add(points[i].scale_scalar(scalars[i]));
    }

    return result;
}

struct BlindedCommitment {
    PolyComm commitments;
    Scalar.FE[] blinders;
}

error InvalidPolycommLength();

// @notice Turns a non-hiding polynomial commitment into a hidding polynomial commitment.
// @notice Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
// INFO: since we are ignoring shifted elements of a commitment, `blinders` only needs to be a Scalar[]
function mask_custom(
    URS storage urs,
    PolyComm memory com,
    Scalar.FE[] memory blinders
) view returns (BlindedCommitment memory) {
    if (com.unshifted.length != blinders.length) {
        revert InvalidPolycommLength();
    }

    BN254.G1Point[] storage unshifted;
    for (uint256 i = 0; i < com.unshifted.length; i++) {
        BN254.G1Point memory g_masked = urs.h.scale_scalar(blinders[i]);
        unshifted.push(g_masked.add(com.unshifted[i]));
    }

    return BlindedCommitment(PolyComm(unshifted), blinders);
}
