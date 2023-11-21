// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/Fields.sol";
import "./Utils.sol";

using { BN254.add, BN254.scale_scalar } for BN254.G1Point;

error MSMInvalidLengths();

struct URS {
    BN254.G1Point[] g;
    BN254.G1Point h;
    mapping(uint256 => PolyCommFlat) lagrange_bases_unshifted;
}

struct PolyComm {
    BN254.G1Point[] unshifted;
    //BN254G1Point shifted;
    // WARN: The previous field is optional but in Solidity we can't have that.
    // for our test circuit (circuit_gen/) it's not necessary
}

struct PolyCommFlat {
    BN254.G1Point[] unshifteds;
    uint unshifted_length;
}

function poly_comm_unflat(PolyCommFlat memory com) pure returns (PolyComm[] memory res) {
    // FIXME: assumes that every unshifted is the same length

    res = new PolyComm[](com.unshifteds.length / com.unshifted_length); 
    for (uint i = 0; i < res.length; i++) {
        uint n = com.unshifted_length;
        BN254.G1Point[] memory unshifted = new BN254.G1Point[](n);
        for (uint j = 0; j < n; j++) {
            unshifted[j] = com.unshifteds[j + i*n];
        }
        res[i] = PolyComm(unshifted);
    }
}

// @notice Executes multi-scalar multiplication between scalars `elm` and commitments `com`.
// @notice If empty, returns a commitment with the point at infinity.
function polycomm_msm(PolyComm[] memory com, Scalar.FE[] memory elm)
    view
    returns (PolyComm memory)
{
    if (com.length == 0 || elm.length == 0) {
        BN254.G1Point[] memory z = new BN254.G1Point[](1);
        z[0] = BN254.point_at_inf();
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

    BN254.G1Point[] memory unshifted = new BN254.G1Point[](unshifted_len);
    for (uint chunk = 0; chunk < unshifted_len; chunk++) {

        // zip with elements and filter scalars that don't have an associated chunk.

        // first get the count of elements that have a chunk:
        uint chunk_length = 0; 
        for (uint i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                chunk_length++;
            }
        }

        // fill arrays
        BN254.G1Point[] memory points = new BN254.G1Point[](chunk_length);
        Scalar.FE[] memory scalars = new Scalar.FE[](chunk_length);
        uint index = 0;
        for (uint i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                points[index] = (com[i].unshifted[chunk]);
                scalars[index] = (elm[i]);
                index++;
            }
        }

        BN254.G1Point memory chunk_msm = naive_msm(points, scalars);
        unshifted[chunk] = chunk_msm;
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
    PolyComm commitment;
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

    uint u_len = com.unshifted.length;
    BN254.G1Point[] memory unshifted = new BN254.G1Point[](u_len);
    for (uint256 i = 0; i < u_len; i++) {
        BN254.G1Point memory g_masked = urs.h.scale_scalar(blinders[i]);
        unshifted[i] = (g_masked.add(com.unshifted[i]));
    }

    return BlindedCommitment(PolyComm(unshifted), blinders);
}

// Reference: Kimchi
// https://github.com/o1-labs/proof-systems/
function calculate_lagrange_bases(
    BN254.G1Point[] memory g,
    BN254.G1Point memory h,
    uint domain_size,
    mapping(uint256 => PolyCommFlat) storage lagrange_bases_unshifted
) {
        uint urs_size = g.length;
        uint num_unshifteds = (domain_size + urs_size - 1) / urs_size;
        BN254.G1Point[][] memory unshifted = new BN254.G1Point[][](num_unshifteds);

        // For each chunk
        for (uint i = 0; i < num_unshifteds; i++) {
            // Initialize the vector with zero curve points
            BN254.G1Point[] memory lg = new BN254.G1Point[](domain_size);
            for (uint j = 0; j < lg.length; j++) {
                lg[j] = BN254.point_at_inf();
            }

            // Overwrite the terms corresponding to that chunk with the SRS curve points
            uint start_offset = i * urs_size;
            uint num_terms = Utils.min((i + 1) * urs_size, domain_size) - start_offset;
            for (uint j = 0; j < num_terms; j++) {
                lg[start_offset + j] = g[j];
            }
            // Apply the IFFT
            BN254.G1Point[] memory lg_fft = Utils.ifft(lg);
            // Append the 'partial Langrange polynomials' to the vector of unshifted chunks
            unshifted[i] = lg_fft;
        }

        PolyCommFlat storage bases_unshifted = lagrange_bases_unshifted[domain_size];
        bases_unshifted.unshifted_length = unshifted.length;

        for (uint i = 0; i < domain_size; i++) {
            for (uint j = 0; j < unshifted.length; j++) {
                bases_unshifted.unshifteds.push(unshifted[j][i]);
            }
        }
}

// Computes the linearization of the evaluations of a (potentially split) polynomial.
// Each given `poly` is associated to a matrix where the rows represent the number of evaluated points,
// and the columns represent potential segments (if a polynomial was split in several parts).
// Note that if one of the polynomial comes specified with a degree bound,
// the evaluation for the last segment is potentially shifted to meet the proof.
function combined_inner_product(
    Scalar.FE[] memory evaluation_points,
    Scalar.FE polyscale,
    Scalar.FE evalscale,
    Scalar.FE[] memory flat_poly_matrices, // this is 3-dim; an array of matrices
    //uint[] poly_shifted, // TODO: not necessary for fiat-shamir
    uint srs_length
) pure returns (Scalar.FE res) {
    res = Scalar.zero();
    Scalar.FE xi_i = Scalar.from(1);

    require(poly_matrices.length == poly_shifted.length);
    for (uint i = 0; i < poly_matrices.length; i++) {
        Scalar.FE[][] memory evals = poly_matrices[i];
        uint shifted = poly_shifted[i];

        if (evals[i].length == 0) {
            continue;
        }

        uint rows = evals.length;
        uint columns = evals.length;
        for (uint col = 0; col < columns; col++) {
            Scalar.FE[] eval = new Scalar[](rows); // column that stores the segment

            for (uint j = 0; j < rows; j++) {
                eval[j] = evals[col + j*columns];
            }
            Scalar.FE term = Polynomial.build_and_eval(eval, evalscale);

            res = res.add(xi_i.mul(term));
            xi_i = xi_i.mul(polyscale);
        }

        // TODO: shifted
    }
}

struct PolyMatrices {
    Scalar.FE[] flat_data;
    uint length;
    uint[] rows; // per matrix
    uint[] cols; // per matrix
}
