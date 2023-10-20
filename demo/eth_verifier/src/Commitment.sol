// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {BN254} from "./BN254.sol";
import {Scalar} from "./Fields.sol";

error MSMInvalidLengths();

struct URS {
    BN254.G1[] g;
    BN254.G1 h;
    mapping(uint256 => PolyComm[]) lagrange_bases;
}

struct PolyComm {
    BN254.G1[] unshifted;
    //BN254G1 shifted;
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
        BN254.G1[] storage z;
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
    BN254.G1[] storage unshifted;

    for (uint256 chunk = 0; chunk < unshifted_len; chunk++) {
        BN254.G1[] storage points;
        Scalar.FE[] storage scalars;

        // zip with elements and filter scalars that don't have an associated chunk.
        for (uint256 i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                points.push(com[i].unshifted[chunk]);
                scalars.push(elm[i]);
            }
        }

        BN254.G1 memory chunk_msm = naive_msm(points, scalars);
        unshifted.push(chunk_msm);
    }
    return PolyComm(unshifted);
}

// @notice Execute a simple multi-scalar multiplication
function naive_msm(BN254.G1[] memory points, Scalar.FE[] memory scalars)
    view
    returns (BN254.G1 memory)
{
    BN254.G1 memory result = BN254.point_at_inf();

    for (uint256 i = 0; i < points.length; i++) {
        result = result.add(points[i].scale_scalar(scalars[i]));
    }

    return result;
}

/*
    //
    // Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
    // If empty, returns a commitment with the point at infinity.
    //
    static msm(com: PolyComm<Group>[], elm: Scalar[]): PolyComm<Group> {
        if (com.length === 0 || elm.length === 0) {
            return new PolyComm<Group>([Group.zero]);
        }

        if (com.length != elm.length) {
            throw new Error("MSM with invalid comm. and scalar counts");
        }

        let unshifted_len = Math.max(...com.map(pc => pc.unshifted.length));
        let unshifted = [];

        for (let chunk = 0; chunk < unshifted_len; chunk++) {
            let points_and_scalars = com
                .map((c, i) => [c, elm[i]] as [PolyComm<Group>, Scalar]) // zip with scalars
                // get rid of scalars that don't have an associated chunk
                .filter(([c, _]) => c.unshifted.length > chunk)
                .map(([c, scalar]) => [c.unshifted[chunk], scalar] as [Group, Scalar]);

            // unzip
            let points = points_and_scalars.map(([c, _]) => c);
            let scalars = points_and_scalars.map(([_, scalar]) => scalar);

            let chunk_msm = this.naiveMSM(points, scalars);
            unshifted.push(chunk_msm);
        }

        let shifted_pairs = com
            .map((c, i) => [c.shifted, elm[i]] as [Group | undefined, Scalar]) // zip with scalars
            .filter(([shifted, _]) => shifted != null)
            .map((zip) => zip as [Group, Scalar]); // zip with scalars

        let shifted = undefined;
        if (shifted_pairs.length != 0) {
            // unzip
            let points = shifted_pairs.map(([c, _]) => c);
            let scalars = shifted_pairs.map(([_, scalar]) => scalar);
            shifted = this.naiveMSM(points, scalars);
        }

        return new PolyComm<Group>(unshifted, shifted);
    }
*/

struct BlindedCommitment {
    PolyComm commitments;
    Scalar.FE[] blinders;
}

error InvalidPolycommLength();

// @notice Turns a non-hiding polynomial commitment into a hidding polynomial commitment.
// @notice Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
// INFO: since we are ignoring shifted elements of a commitment, `blinders` only needs to be a Scalar[]
function mask_custom(
    PolyComm memory com,
    Scalar.FE[] memory blinders,
    URS memory urs
) view returns (BlindedCommitment memory) {
    if (com.length != blinders.length) {
        revert InvalidPolycommLength();
    }

    BN254.G1[] storage unshifted;
    for (uint256 i = 0; i < com.length; i++) {
        BN254.G1 memory g_masked = urs.h.scale_scalar(blinders[i]);
        unshifted.push(g_masked.add(com.unshifted[i]));
    }

    return BlindedCommitment(PolyComm(unshifted), blinders);
}
