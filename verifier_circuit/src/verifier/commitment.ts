import { ForeignGroup, Scalar } from 'o1js';
import { ForeignBase } from '../foreign_fields/foreign_field.js';
import { ForeignScalar } from '../foreign_fields/foreign_scalar.js';
import { AggregatedEvaluationProof, bPoly, bPolyCoefficients, combineCommitments } from '../poly_commitment/commitment.js';
import { ScalarChallenge } from '../prover/prover.js';
import { SRS } from '../SRS.js';
import { sqrtBase } from '../util/field.js';
import { logField } from '../util/log.js';
import { powScalar } from "../util/scalar.js";

export function finalVerify(
    srs: SRS,
    group_map: BWParameters,
    batch: AggregatedEvaluationProof
): boolean {
    const nonzero_length = srs.g.length;

    const max_rounds = Math.ceil(Math.log2(nonzero_length));

    const padded_length = 1 << max_rounds;

    const endo_r = ForeignScalar.from("0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1");

    const zero = ForeignBase.from(0);
    const padding = padded_length - nonzero_length;
    let points = [srs.h];
    points = points.concat(srs.g);
    points.concat(new Array(padding).fill(new ForeignGroup(zero, zero)));

    let scalars = new Array(padded_length + 1).fill(zero);

    const rand_base = ForeignScalar.from(0x068EC6E24481F548A1E59ED41FA4459C76A1220B34376903C5EC15D08B406378n);
    const sg_rand_base = ForeignScalar.from(0x36AF07E9262ADDD8B4FA1CAB629745BD539B2546784D54686B5F6F2EDAA5C8A5n);

    const {
        sponge,
        evaluation_points,
        polyscale,
        evalscale,
        evaluations,
        opening,
        combined_inner_product,
    } = batch;

    // absorb x - 2^n where n is the bits used to represent the scalar field modulus
    const MODULUS_BITS = 255;
    sponge.absorbFr(combined_inner_product.sub( powScalar(ForeignScalar.from(2), MODULUS_BITS) ));

    const t = sponge.challengeFq();
    const u = group_map.toGroup(t);

    const chal_tuple = opening.challenges(endo_r, sponge);
    const chal = chal_tuple[0];
    const chal_inv = chal_tuple[1];

    sponge.absorbGroup(opening.delta);
    let c = new ScalarChallenge(sponge.challenge()).toField(endo_r);

    let scale = ForeignScalar.from(1);
    let res = ForeignScalar.from(0);
    for (const e of evaluation_points) {
        const term = bPoly(chal, e);
        res = res.add(scale.mul(term));
        scale = scale.mul(evalscale);
    }
    const b0 = res;

    const s = bPolyCoefficients(chal);

    const neg_rand_base = rand_base.neg();

    points.push(opening.sg);
    scalars.push(neg_rand_base.mul(opening.z1).sub(sg_rand_base));

    const terms = s.map((s) => sg_rand_base.mul(s));
    for (const [i, term] of terms.entries()) {
        scalars[i + 1] = scalars[i + 1].add(term);
    }
    console.log("finished terms");

    scalars[0] = scalars[0].sub(rand_base.mul(opening.z2));

    scalars.push(neg_rand_base.mul(opening.z1).mul(b0));
    points.push(u!);

    const rand_base_c = c.mul(rand_base);
    const length = Math.min(opening.lr.length, Math.min(chal_inv.length, chal.length));
    console.log("start loop");
    for (let i = 0; i < length; i++) {
        const l = opening.lr[i][0];
        const r = opening.lr[i][1];
        const u_inv = chal_inv[i];
        const u = chal[i];

        points.push(l);
        scalars.push(rand_base_c.mul(u_inv));

        points.push(r)
        scalars.push(rand_base_c.mul(u));
    }

    combineCommitments(
        evaluations,
        scalars,
        points,
        polyscale,
        rand_base_c
    );

    scalars.push(rand_base_c.mul(combined_inner_product));
    points.push(u!);

    scalars.push(rand_base);
    points.push(opening.delta);

    console.log("points len: ", points.length);
    console.log("scalars len: ", scalars.length);

    logField("scalars last: ", scalars[scalars.length - 1]);
    logField("points last: ", points[points.length - 1].x);

    console.log("end of verifier");
    // missing: final MSM

    return false;
}

export class BWParameters {
    u: ForeignBase
    fu: ForeignBase
    sqrtNegThreeUSquaredMinusUOver2: ForeignBase
    sqrtNegThreeUSquared: ForeignBase
    invThreeUSquared: ForeignBase

    constructor() {
        // constants which only depend on the group (Pallas). These were taken from the Rust implementation.
        this.u = ForeignBase.from(0x0000000000000000000000000000000000000000000000000000000000000001n);
        this.fu = ForeignBase.from(0x0000000000000000000000000000000000000000000000000000000000000006n);
        this.sqrtNegThreeUSquaredMinusUOver2 = ForeignBase.from(0x12CCCA834ACDBA712CAAD5DC57AAB1B01D1F8BD237AD31491DAD5EBDFDFE4AB9n);
        this.sqrtNegThreeUSquared = ForeignBase.from(0x25999506959B74E25955ABB8AF5563603A3F17A46F5A62923B5ABD7BFBFC9573n);
        this.invThreeUSquared = ForeignBase.from(0x2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC18465FD5B88A612661E209E00000001n);
    }

    toGroup(t: ForeignScalar): ForeignGroup | undefined {
        const t2 = t.mul(t);
        let alpha_inv = t2;
        alpha_inv = alpha_inv.add(this.fu);
        alpha_inv = alpha_inv.mul(t2);

        const alpha = alpha_inv.inv();

        let x1 = t2;
        x1 = x1.mul(x1);
        x1 = x1.mul(alpha);
        x1 = x1.mul(this.sqrtNegThreeUSquared);
        x1 = this.sqrtNegThreeUSquaredMinusUOver2.sub(x1);

        const x2 = this.u.neg().sub(x1);

        const t2_plus_fu = t2.add(this.fu);
        const t2_inv = alpha.mul(t2_plus_fu);
        let x3 = t2_plus_fu.mul(t2_plus_fu);
        x3 = x3.mul(t2_inv);
        x3 = x3.mul(this.invThreeUSquared);
        x3 = this.u.sub(x3);

        const xvec = [x1, x2, x3];
        for (const x of xvec) {
            // curve equation: y^2 = x^3 + 5
            const ysqrd = x.mul(x).mul(x).add(ForeignBase.from(5));
            const y = sqrtBase(ysqrd);
            if (y) return ForeignGroup.fromFields([x, y]);
        }

        return undefined;
    }
}
/*
    /// This function verifies batch of batched polynomial commitment opening proofs
    ///     batch: batch of batched polynomial commitment opening proofs
    ///          vector of evaluation points
    ///          polynomial scaling factor for this batched openinig proof
    ///          eval scaling factor for this batched openinig proof
    ///          batch/vector of polycommitments (opened in this batch), evaluation vectors and, optionally, max degrees
    ///          opening proof for this batched opening
    ///     oracle_params: parameters for the random oracle argument
    ///     randomness source context
    ///     RETURN: verification status
    pub fn verify<EFqSponge, RNG>(
        &self,
        group_map: &G::Map,
        batch: &mut [BatchEvaluationProof<G, EFqSponge, OpeningProof<G>>],
        rng: &mut RNG,
    ) -> bool
    where
        EFqSponge: FqSponge<G::BaseField, G, G::ScalarField>,
        RNG: RngCore + CryptoRng,
        G::BaseField: PrimeField,
    {
        // Verifier checks for all i,
        // c_i Q_i + delta_i = z1_i (G_i + b_i U_i) + z2_i H
        //
        // if we sample evalscale at random, it suffices to check
        //
        // 0 == sum_i evalscale^i (c_i Q_i + delta_i - ( z1_i (G_i + b_i U_i) + z2_i H ))
        //
        // and because each G_i is a multiexp on the same array self.g, we
        // can batch the multiexp across proofs.
        //
        // So for each proof in the batch, we add onto our big multiexp the following terms
        // evalscale^i c_i Q_i
        // evalscale^i delta_i
        // - (evalscale^i z1_i) G_i
        // - (evalscale^i z2_i) H
        // - (evalscale^i z1_i b_i) U_i

        // We also check that the sg component of the proof is equal to the polynomial commitment
        // to the "s" array

        let nonzero_length = self.g.len();

        let max_rounds = math::ceil_log2(nonzero_length);

        let padded_length = 1 << max_rounds;

        let (_, endo_r) = endos::<G>();

        // TODO: This will need adjusting
        let padding = padded_length - nonzero_length;
        let mut points = vec![self.h];
        points.extend(self.g.clone());
        points.extend(vec![G::zero(); padding]);

        let mut scalars = vec![G::ScalarField::zero(); padded_length + 1];
        assert_eq!(scalars.len(), points.len());

        // sample randomiser to scale the proofs with
        let rand_base = G::ScalarField::rand(rng);
        let sg_rand_base = G::ScalarField::rand(rng);

        let mut rand_base_i = G::ScalarField::one();
        let mut sg_rand_base_i = G::ScalarField::one();

        for BatchEvaluationProof {
            sponge,
            evaluation_points,
            polyscale,
            evalscale,
            evaluations,
            opening,
            combined_inner_product,
        } in batch.iter_mut()
        {
            sponge.absorb_fr(&[shift_scalar::<G>(*combined_inner_product)]);

            let t = sponge.challenge_fq();
            let u: G = to_group(group_map, t);

            let Challenges { chal, chal_inv } = opening.challenges::<EFqSponge>(&endo_r, sponge);

            sponge.absorb_g(&[opening.delta]);
            let c = ScalarChallenge(sponge.challenge()).to_field(&endo_r);

            // < s, sum_i evalscale^i pows(evaluation_point[i]) >
            // ==
            // sum_i evalscale^i < s, pows(evaluation_point[i]) >
            let b0 = {
                let mut scale = G::ScalarField::one();
                let mut res = G::ScalarField::zero();
                for &e in evaluation_points.iter() {
                    let term = b_poly(&chal, e);
                    res += &(scale * term);
                    scale *= *evalscale;
                }
                res
            };

            let s = b_poly_coefficients(&chal);

            let neg_rand_base_i = -rand_base_i;

            // TERM
            // - rand_base_i z1 G
            //
            // we also add -sg_rand_base_i * G to check correctness of sg.
            points.push(opening.sg);
            scalars.push(neg_rand_base_i * opening.z1 - sg_rand_base_i);

            // Here we add
            // sg_rand_base_i * ( < s, self.g > )
            // =
            // < sg_rand_base_i s, self.g >
            //
            // to check correctness of the sg component.
            {
                let terms: Vec<_> = s.par_iter().map(|s| sg_rand_base_i * s).collect();

                for (i, term) in terms.iter().enumerate() {
                    scalars[i + 1] += term;
                }
            }

            // TERM
            // - rand_base_i * z2 * H
            scalars[0] -= &(rand_base_i * opening.z2);

            // TERM
            // -rand_base_i * (z1 * b0 * U)
            scalars.push(neg_rand_base_i * (opening.z1 * b0));
            points.push(u);

            // TERM
            // rand_base_i c_i Q_i
            // = rand_base_i c_i
            //   (sum_j (chal_invs[j] L_j + chals[j] R_j) + P_prime)
            // where P_prime = combined commitment + combined_inner_product * U
            let rand_base_i_c_i = c * rand_base_i;
            for ((l, r), (u_inv, u)) in opening.lr.iter().zip(chal_inv.iter().zip(chal.iter())) {
                points.push(*l);
                scalars.push(rand_base_i_c_i * u_inv);

                points.push(*r);
                scalars.push(rand_base_i_c_i * u);
            }

            // TERM
            // sum_j evalscale^j (sum_i polyscale^i f_i) (elm_j)
            // == sum_j sum_i evalscale^j polyscale^i f_i(elm_j)
            // == sum_i polyscale^i sum_j evalscale^j f_i(elm_j)
            combine_commitments(
                evaluations,
                &mut scalars,
                &mut points,
                *polyscale,
                rand_base_i_c_i,
            );

            scalars.push(rand_base_i_c_i * *combined_inner_product);
            points.push(u);

            scalars.push(rand_base_i);
            points.push(opening.delta);

            rand_base_i *= &rand_base;
            sg_rand_base_i *= &sg_rand_base;
        }

        // verify the equation
        let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
        VariableBaseMSM::multi_scalar_mul(&points, &scalars) == G::Projective::zero()
    }
*/
