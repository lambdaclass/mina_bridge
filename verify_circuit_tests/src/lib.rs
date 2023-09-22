use ark_ec::{short_weierstrass_jacobian::GroupAffine, AffineCurve};
use ark_ff::{One, PrimeField};
use ark_poly::domain::EvaluationDomain;
use kimchi::{
    curve::KimchiCurve,
    error::VerifyError,
    mina_curves::pasta::{Fq, PallasParameters},
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    o1_utils::FieldHelpers,
    poly_commitment::PolyComm,
    proof::{LookupEvaluations, PointEvaluations, ProofEvaluations, ProverProof},
    verifier_index::VerifierIndex,
};
use serde::Serialize;

pub type PallasGroup = GroupAffine<PallasParameters>;

pub type SpongeParams = PlonkSpongeConstantsKimchi;
pub type BaseSponge = DefaultFqSponge<PallasParameters, SpongeParams>;
pub type ScalarSponge = DefaultFrSponge<Fq, SpongeParams>;

/// Enforce the length of evaluations inside [`Proof`].
/// Atm, the length of evaluations(both `zeta` and `zeta_omega`) SHOULD be 1.
/// The length value is prone to future change.
pub fn check_proof_evals_len<G>(proof: &ProverProof<G>) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    let ProofEvaluations {
        w,
        z,
        s,
        coefficients,
        lookup,
        generic_selector,
        poseidon_selector,
    } = &proof.evals;

    let check_eval_len = |eval: &PointEvaluations<Vec<_>>| -> Result<(), VerifyError> {
        if eval.zeta.len().is_one() && eval.zeta_omega.len().is_one() {
            Ok(())
        } else {
            Err(VerifyError::IncorrectEvaluationsLength)
        }
    };

    for w_i in w {
        check_eval_len(w_i)?;
    }
    check_eval_len(z)?;
    for s_i in s {
        check_eval_len(s_i)?;
    }
    for coeff in coefficients {
        check_eval_len(coeff)?;
    }
    if let Some(LookupEvaluations {
        sorted,
        aggreg,
        table,
        runtime,
    }) = lookup
    {
        for sorted_i in sorted {
            check_eval_len(sorted_i)?;
        }
        check_eval_len(aggreg)?;
        check_eval_len(table)?;
        if let Some(runtime) = &runtime {
            check_eval_len(runtime)?;
        }
    }
    check_eval_len(generic_selector)?;
    check_eval_len(poseidon_selector)?;

    Ok(())
}

/// Useful for serializing into JSON and importing in Typescript tests.
#[derive(Serialize)]
pub struct UncompressedPoint {
    pub x: String,
    pub y: String,
}

/// Useful for serializing into JSON and importing in Typescript tests.
#[derive(Serialize)]
pub struct UncompressedPolyComm {
    pub unshifted: Vec<UncompressedPoint>,
    pub shifted: Option<UncompressedPoint>,
}

impl From<&PolyComm<PallasGroup>> for UncompressedPolyComm {
    fn from(value: &PolyComm<PallasGroup>) -> Self {
        Self {
            unshifted: value
                .unshifted
                .iter()
                .map(|u| UncompressedPoint {
                    x: u.x.to_biguint().to_string(),
                    y: u.y.to_biguint().to_string(),
                })
                .collect(),
            shifted: value.shifted.map(|s| UncompressedPoint {
                x: s.x.to_biguint().to_string(),
                y: s.y.to_biguint().to_string(),
            }),
        }
    }
}

/// Execute step 1 of partial verification
pub fn to_batch_step1<G>(proof: &ProverProof<G>) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    println!("to_batch(), step 1: Commit to the negated public input polynomial.");
    check_proof_evals_len(proof)?;
    Ok(())
}

/// Execute step 2 of partial verification
pub fn to_batch_step2<G>(
    verifier_index: &VerifierIndex<G>,
    public_input: &[<G as AffineCurve>::ScalarField],
) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    println!("to_batch(), step 2: Commit to the negated public input polynomial.");
    let public_comm = {
        if public_input.len() != verifier_index.public {
            return Err(VerifyError::IncorrectPubicInputLength(
                verifier_index.public,
            ));
        }
        let lgr_comm = verifier_index
            .srs()
            .lagrange_bases
            .get(&verifier_index.domain.size())
            .expect("pre-computed committed lagrange bases not found");
        let com: Vec<_> = lgr_comm.iter().take(verifier_index.public).collect();
        let elm: Vec<_> = public_input.iter().map(|s| -*s).collect();
        let public_comm = PolyComm::<G>::multi_scalar_mul(&com, &elm);
        verifier_index
            .srs()
            .mask_custom(
                public_comm,
                &PolyComm {
                    unshifted: vec![G::ScalarField::one(); 1],
                    shifted: None,
                },
            )
            .unwrap()
            .commitment
    };
    println!(
        "Done, public_comm: {:?}",
        public_comm.unshifted[0].to_string()
    );
    Ok(())
}
