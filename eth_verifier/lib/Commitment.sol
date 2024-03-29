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

        BN254.G1Point memory chunk_msm = naive_msm(points, scalars);
        unshifted[chunk] = chunk_msm;
        ++chunk;
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
        if (evaluations[i].commitment.unshifted.length == 0) continue;

        PolyComm memory commitment = evaluations[i].commitment;
        Scalar.FE[][2] memory inner_evaluations = evaluations[i].evaluations;
        uint256 commitment_steps = commitment.unshifted.length;
        uint256 evaluation_steps = inner_evaluations[0].length;
        uint256 steps = commitment_steps > evaluation_steps ? commitment_steps : evaluation_steps;

        for (uint256 j = 0; j < steps; j++) {
            if (j < commitment_steps) {
                BN254.G1Point memory comm_ch = commitment.unshifted[j];
                poly_commitment = poly_commitment.add(comm_ch.scale_scalar(rand_base.mul(xi_i)));
            }
            if (j < evaluation_steps) {
                for (uint256 k = 0; k < inner_evaluations.length; k++) {
                    acc[k] = acc[k].add(inner_evaluations[k][j].mul(xi_i));
                }
            }
            xi_i = xi_i.mul(polyscale);
        }
        // TODO: degree bound, shifted part
    }
}
