// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./bn254/BN254.sol";
import "./bn254/BN256G2.sol";
import "./bn254/Fields.sol";
import "./Utils.sol";
import "./Polynomial.sol";

using {BN254.add, BN254.scale_scalar, BN254.neg} for BN254.G1Point;
using {Scalar.neg, Scalar.add, Scalar.sub, Scalar.mul, Scalar.inv, Scalar.double, Scalar.pow} for Scalar.FE;
using {Polynomial.is_zero} for Polynomial.Dense;

error MSMInvalidLengths();

struct URS {
    BN254.G1Point[] g;
    BN254.G1Point h;
}

struct URSG2 {
    BN254.G2Point[] g;
    BN254.G2Point h;
}

function create_trusted_setup(Scalar.FE x, uint256 depth) view returns (URS memory) {
    Scalar.FE x_pow = Scalar.one();
    BN254.G1Point[] memory g = new BN254.G1Point[](depth);
    BN254.G1Point memory h = BN254.P1(); // should be blake2b hash

    for (uint256 i = 0; i < depth; i++) {
        g[i] = BN254.P1().scale_scalar(x_pow);
        x_pow = x_pow.mul(x);
    }

    return URS(g, h);
}

function create_trusted_setup_g2(Scalar.FE x, uint256 depth) view returns (URSG2 memory) {
    BN254.G2Point memory p2 = BN254.P2();

    Scalar.FE x_pow = Scalar.one();
    BN254.G2Point[] memory g = new BN254.G2Point[](depth);
    BN254.G2Point memory h = BN254.P2(); // should be blake2b hash, see precompile 0x09

    for (uint256 i = 0; i < depth; i++) {
        g[i] = BN256G2.ECTwistMul(Scalar.FE.unwrap(x_pow), p2);
        x_pow = x_pow.mul(x);
    }

    return URSG2(g, h);
}

struct PairingURS {
    URS full_urs;
    URSG2 verifier_urs;
    mapping(uint256 => PolyCommFlat) lagrange_bases_unshifted;
}

function random_lagrange_bases(PairingURS storage urs, uint256 domain_size) {
    uint256[] memory u_lengths = new uint256[](1);
    u_lengths[0] = domain_size;

    BN254.G1Point[] memory unshifteds = new BN254.G1Point[](domain_size);
    for (uint256 i = 0; i < domain_size; i++) {
        unshifteds[i] = BN254.P1();
    }

    PolyCommFlat memory comms = PolyCommFlat(unshifteds, u_lengths);
    urs.lagrange_bases_unshifted[domain_size] = comms;
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

// @notice this structure flattens the fields of `PolyComm`.
// its motivation lies in Solidity's inability to store nested arrays
// in a mapping.
struct PolyCommFlat {
    BN254.G1Point[] unshifteds;
    uint256[] unshifted_lengths;
}

function poly_comm_unflat(PolyCommFlat memory com) pure returns (PolyComm[] memory res) {
    uint256 comm_count = com.unshifted_lengths.length;
    res = new PolyComm[](comm_count);
    uint256 index = 0;
    for (uint256 i = 0; i < comm_count; i++) {
        uint256 n = com.unshifted_lengths[i];
        BN254.G1Point[] memory unshifted = new BN254.G1Point[](n);
        for (uint256 j = 0; j < n; j++) {
            unshifted[j] = com.unshifteds[index];
            index++;
        }
        // TODO: shifted is fixed to infinity
        BN254.G1Point memory shifted = BN254.point_at_inf();
        res[i] = PolyComm(unshifted, shifted);
    }
}

function poly_comm_flat(PolyComm[] memory com) pure returns (PolyCommFlat memory) {
    uint256 total_length = 0;
    uint256[] memory unshifted_lengths = new uint256[](com.length);
    for (uint256 i = 0; i < com.length; i++) {
        total_length += com[i].unshifted.length;
        unshifted_lengths[i] = com[i].unshifted.length;
    }
    BN254.G1Point[] memory unshifteds = new BN254.G1Point[](total_length);

    uint256 index = 0;
    for (uint256 i = 0; i < com.length; i++) {
        for (uint256 j = 0; j < com[i].unshifted.length; j++) {
            unshifteds[index] = com[i].unshifted[j];
            index++;
        }
    }

    return PolyCommFlat(unshifteds, unshifted_lengths);
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
    for (uint256 chunk = 0; chunk < unshifted_len; chunk++) {
        // zip with elements and filter scalars that don't have an associated chunk.

        // first get the count of elements that have a chunk:
        uint256 chunk_length = 0;
        for (uint256 i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                chunk_length++;
            }
        }

        // fill arrays
        BN254.G1Point[] memory points = new BN254.G1Point[](chunk_length);
        Scalar.FE[] memory scalars = new Scalar.FE[](chunk_length);
        uint256 index = 0;
        for (uint256 i = 0; i < n; i++) {
            if (com[i].unshifted.length > chunk) {
                points[index] = (com[i].unshifted[chunk]);
                scalars[index] = (elm[i]);
                index++;
            }
        }

        BN254.G1Point memory chunk_msm = naive_msm(points, scalars);
        unshifted[chunk] = chunk_msm;
    }
    // TODO: shifted is fixed to infinity
    BN254.G1Point memory shifted = BN254.point_at_inf();
    return PolyComm(unshifted, shifted);
}

// @notice Execute a simple multi-scalar multiplication with points on G1
function naive_msm(BN254.G1Point[] memory points, Scalar.FE[] memory scalars) view returns (BN254.G1Point memory) {
    BN254.G1Point memory result = BN254.point_at_inf();

    for (uint256 i = 0; i < points.length; i++) {
        result = result.add(points[i].scale_scalar(scalars[i]));
    }

    return result;
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

struct BlindedCommitment {
    PolyComm commitment;
    Scalar.FE[] blinders;
}

error InvalidPolycommLength();

// @notice Turns a non-hiding polynomial commitment into a hidding polynomial commitment.
// @notice Transforms each given `<a, G>` into `(<a, G> + wH, w)`.
// INFO: since we are ignoring shifted elements of a commitment, `blinders` only needs to be a Scalar[]
function mask_custom(URS storage urs, PolyComm memory com, Scalar.FE[] memory blinders)
    view
    returns (BlindedCommitment memory)
{
    if (com.unshifted.length != blinders.length) {
        revert InvalidPolycommLength();
    }

    uint256 u_len = com.unshifted.length;
    BN254.G1Point[] memory unshifted = new BN254.G1Point[](u_len);
    for (uint256 i = 0; i < u_len; i++) {
        BN254.G1Point memory g_masked = urs.h.scale_scalar(blinders[i]);
        unshifted[i] = (g_masked.add(com.unshifted[i]));
    }

    // TODO: shifted is fixed to infinity
    BN254.G1Point memory shifted = BN254.point_at_inf();
    return BlindedCommitment(PolyComm(unshifted, shifted), blinders);
}

// @notice multiplies each commitment chunk of f with powers of zeta^n
// @notice note that it ignores the shifted part.
function chunk_commitment(PolyComm memory self, Scalar.FE zeta_n) view returns (PolyComm memory) {
    BN254.G1Point memory res = BN254.point_at_inf();

    uint256 length = self.unshifted.length;
    for (uint256 i = 0; i < length; i++) {
        BN254.G1Point memory chunk = self.unshifted[length - i - 1];

        res = res.scale_scalar(zeta_n);
        res = res.add(chunk);
    }

    BN254.G1Point[] memory unshifted = new BN254.G1Point[](1);
    unshifted[0] = res;

    // TODO: shifted is fixed to infinity
    BN254.G1Point memory shifted = BN254.point_at_inf();
    return PolyComm(unshifted, shifted);
}

// @notice substracts two polynomial commitments
function sub_polycomms(PolyComm memory self, PolyComm memory other) view returns (PolyComm memory res) {
    uint256 n_self = self.unshifted.length;
    uint256 n_other = other.unshifted.length;
    uint256 n = Utils.max(n_self, n_other);
    res.unshifted = new BN254.G1Point[](n);

    for (uint i = 0; i < n; i++) {
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

    for (uint i = 0; i < n; i++) {
        res.unshifted[i] = res.unshifted[i].scale_scalar(c);
    }
}

// Reference: Kimchi
// https://github.com/o1-labs/proof-systems/
function calculate_lagrange_bases(
    BN254.G1Point[] memory g,
    BN254.G1Point memory h,
    uint256 domain_size,
    mapping(uint256 => PolyCommFlat) storage lagrange_bases_unshifted
) {
    uint256 urs_size = g.length;
    uint256 num_unshifteds = (domain_size + urs_size - 1) / urs_size;
    BN254.G1Point[][] memory unshifted = new BN254.G1Point[][](num_unshifteds);

    // For each chunk
    for (uint256 i = 0; i < num_unshifteds; i++) {
        // Initialize the vector with zero curve points
        BN254.G1Point[] memory lg = new BN254.G1Point[](domain_size);
        for (uint256 j = 0; j < lg.length; j++) {
            lg[j] = BN254.point_at_inf();
        }

        // Overwrite the terms corresponding to that chunk with the SRS curve points
        uint256 start_offset = i * urs_size;
        uint256 num_terms = Utils.min((i + 1) * urs_size, domain_size) - start_offset;
        for (uint256 j = 0; j < num_terms; j++) {
            lg[start_offset + j] = g[j];
        }
        // Apply the IFFT
        BN254.G1Point[] memory lg_fft = Utils.ifft(lg);
        // Append the 'partial Langrange polynomials' to the vector of unshifted chunks
        unshifted[i] = lg_fft;
    }

    PolyCommFlat storage bases_unshifted = lagrange_bases_unshifted[domain_size];
    uint256[] memory unshifted_lengths = new uint256[](num_unshifteds);
    for (uint256 i = 0; i < num_unshifteds; i++) {
        unshifted_lengths[i] = 0;
    }
    bases_unshifted.unshifted_lengths = unshifted_lengths;

    for (uint256 i = 0; i < domain_size; i++) {
        for (uint256 j = 0; j < unshifted.length; j++) {
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
    Scalar.FE[][2][] memory polys,
    //uint[] poly_shifted, // TODO: not necessary for fiat-shamir
    uint256 _srs_length
) pure returns (Scalar.FE res) {
    res = Scalar.zero();
    Scalar.FE xi_i = Scalar.from(1);

    for (uint256 i = 0; i < polys.length; i++) {
        Scalar.FE[][2] memory matrix = polys[i];
        if (matrix[0].length == 0 || matrix[1].length == 0) continue; // skip empty evaluations

        uint256 rows = 2; // WARN: magic number, this is because we only have two evaluation points in our case.
        uint256 cols = 1; // WARN: magic number, this is because we only have one segment per poly (non-linearized).

        require(matrix.length == rows, "rows are not of the expected size");
        require(matrix[0].length == 1, "cols are not of the expected size");
        require(matrix[1].length == 1, "cols are not of the expected size");

        for (uint256 col = 0; col < cols; col++) {
            Scalar.FE[] memory eval = new Scalar.FE[](rows); // column that stores the segment
            for (uint256 row = 0; row < rows; row++) {
                eval[row] = matrix[row][col];
            }

            Scalar.FE term = Polynomial.build_and_eval(eval, evalscale);

            res = res.add(xi_i.mul(term));
            xi_i = xi_i.mul(polyscale);
        }

        // TODO: shifted
    }
}

/// @notice commits a polynomial using a URS in G2 of size `n`, splitting in at least
/// @notice `num_chunks` unshifted chunks.
function commit_non_hiding(URSG2 memory self, Polynomial.Dense memory plnm, uint256 num_chunks)
    view
    returns (PolyCommG2 memory comm)
{
    bool is_zero = plnm.is_zero();

    uint256 basis_len = self.g.length;
    uint256 coeffs_len = plnm.coeffs.length;

    uint256 unshifted_len = is_zero ? 1 : coeffs_len / basis_len;
    uint256 odd_chunk_len = coeffs_len % basis_len;
    if (odd_chunk_len != 0) unshifted_len += 1;
    BN254.G2Point[] memory unshifted = new BN254.G2Point[](Utils.max(unshifted_len, num_chunks));

    if (is_zero) {
        unshifted[0] = BN254.point_at_inf_g2();
    } else {
        // whole chunks
        for (uint256 i = 0; i < coeffs_len / basis_len; i++) {
            Scalar.FE[] memory coeffs_chunk = new Scalar.FE[](basis_len);
            for (uint256 j = 0; j < coeffs_chunk.length; j++) {
                coeffs_chunk[j] = plnm.coeffs[j + i * basis_len];
            }

            unshifted[i] = naive_msm(self.g, coeffs_chunk);
        }

        // odd chunk
        if (odd_chunk_len != 0) {
            Scalar.FE[] memory coeffs_chunk = new Scalar.FE[](basis_len);
            for (uint256 j = 0; j < odd_chunk_len; j++) {
                coeffs_chunk[j] = plnm.coeffs[j + (coeffs_len / basis_len) * basis_len];
            }
            for (uint256 j = odd_chunk_len; j < coeffs_chunk.length; j++) {
                coeffs_chunk[j] = Scalar.zero();
            } // FIXME: fill with zeros so I don't have to modify the MSM algorithm

            unshifted[unshifted_len - 1] = naive_msm(self.g, coeffs_chunk);
        }
    }

    for (uint256 i = unshifted_len; i < num_chunks; i++) {
        unshifted[i] = BN254.point_at_inf_g2();
    }

    comm.unshifted = unshifted;
}

// this represents an array of matrices of polynomial commitments
// evaluations, in a flat manner. This was made to temporarily speed up
// development and ignore details. In reality I think that there're only two
// possible evaluations for every commitment so there's a fixed dimension. This
// might me implementable as a 3D array composed of a fixed-length one and two
// variable length.
// TODO: could be replaced, needs a bit of research
// relevant: https://github.com/o1-labs/proof-systems/blob/a27270040c08eb2c99e37f90833ee7bfb1fd22f5/kimchi/src/verifier.rs#L566
struct PolyMatrices {
    Scalar.FE[] data;
    uint256 length;
    uint256[] rows; // row count per matrix
    uint256[] cols; // col count per matrix
    uint256[] starts; // index at which every matrix starts
}
