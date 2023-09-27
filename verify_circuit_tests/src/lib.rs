use ark_ec::AffineCurve;
use ark_ff::{One, PrimeField};
use ark_poly::domain::EvaluationDomain;
use kimchi::{
    curve::KimchiCurve,
    error::VerifyError,
    mina_curves::pasta::{Fq, Pallas, PallasParameters},
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    o1_utils::FieldHelpers,
    poly_commitment::PolyComm,
    proof::{
        LookupCommitments, LookupEvaluations, PointEvaluations, ProofEvaluations,
        ProverCommitments, ProverProof, RecursionChallenge,
    },
    verifier_index::VerifierIndex,
};
use serde::Serialize;

pub type PallasScalar = <Pallas as AffineCurve>::ScalarField;
pub type PallasPointEvals = PointEvaluations<Vec<PallasScalar>>;

pub struct SerializablePallasScalar {
    element: PallasScalar,
}

impl Serialize for SerializablePallasScalar {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.element.to_string())
    }
}

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
#[derive(Serialize, Debug)]
pub struct UncompressedPoint {
    pub x: String,
    pub y: String,
}

/// Useful for serializing into JSON and importing in Typescript tests.
#[derive(Serialize, Debug)]
pub struct UncompressedPolyComm {
    pub unshifted: Vec<UncompressedPoint>,
    pub shifted: Option<UncompressedPoint>,
}

impl From<&PolyComm<Pallas>> for UncompressedPolyComm {
    fn from(value: &PolyComm<Pallas>) -> Self {
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

#[derive(Serialize, Debug)]
pub struct VerifierIndexTS {
    //srs: SRS<Pallas>,
    domain_size: usize,
    public: usize,

    sigma_comm: Vec<UncompressedPolyComm>, // of size PERMUTS
    coefficients_comm: Vec<UncompressedPolyComm>, // of size COLUMNS
    generic_comm: UncompressedPolyComm,

    psm_comm: UncompressedPolyComm,

    complete_add_comm: UncompressedPolyComm,
    mul_comm: UncompressedPolyComm,
    emul_comm: UncompressedPolyComm,
    endomul_scalar_comm: UncompressedPolyComm,
}

impl From<&VerifierIndex<Pallas>> for VerifierIndexTS {
    fn from(value: &VerifierIndex<Pallas>) -> Self {
        let VerifierIndex {
            domain,
            public,
            sigma_comm,
            coefficients_comm,
            generic_comm,
            psm_comm,
            complete_add_comm,
            mul_comm,
            emul_comm,
            endomul_scalar_comm,
            ..
        } = value;
        VerifierIndexTS {
            domain_size: domain.size(),
            public: public.clone(),
            sigma_comm: sigma_comm.iter().map(UncompressedPolyComm::from).collect(),
            coefficients_comm: coefficients_comm
                .iter()
                .map(UncompressedPolyComm::from)
                .collect(),
            generic_comm: UncompressedPolyComm::from(generic_comm),
            psm_comm: UncompressedPolyComm::from(psm_comm),
            complete_add_comm: UncompressedPolyComm::from(complete_add_comm),
            mul_comm: UncompressedPolyComm::from(mul_comm),
            emul_comm: UncompressedPolyComm::from(emul_comm),
            endomul_scalar_comm: UncompressedPolyComm::from(endomul_scalar_comm),
        }
    }
}

#[derive(Serialize)]
pub struct ProverCommitmentsTS {
    w_comm: Vec<UncompressedPolyComm>, // size COLUMNS
    z_comm: UncompressedPolyComm,
    t_comm: UncompressedPolyComm,
    lookup: Option<LookupCommitments<Pallas>>, // doesn't really matter as it'll be null for
                                               // our tests
}

impl From<&ProverCommitments<Pallas>> for ProverCommitmentsTS {
    fn from(value: &ProverCommitments<Pallas>) -> Self {
        let ProverCommitments {
            w_comm,
            z_comm,
            t_comm,
            lookup,
        } = value;

        ProverCommitmentsTS {
            w_comm: w_comm.iter().map(UncompressedPolyComm::from).collect(),
            z_comm: UncompressedPolyComm::from(z_comm),
            t_comm: UncompressedPolyComm::from(t_comm),
            lookup: lookup.clone(),
        }
    }
}

#[derive(Serialize)]
pub struct RecursionChallengeTS {
    chals: Vec<SerializablePallasScalar>,
    comm: UncompressedPolyComm,
}

impl From<&RecursionChallenge<Pallas>> for RecursionChallengeTS {
    fn from(value: &RecursionChallenge<Pallas>) -> Self {
        let RecursionChallenge { chals, comm } = value;

        RecursionChallengeTS {
            chals: chals
                .iter()
                .map(|s| SerializablePallasScalar { element: s.clone() })
                .collect(),
            comm: UncompressedPolyComm::from(comm),
        }
    }
}

#[derive(Serialize)]
pub struct ProverProofTS {
    evals: ProofEvaluations<PallasPointEvals>,
    prev_challenges: Vec<RecursionChallengeTS>,
    commitments: ProverCommitmentsTS,
}

impl From<&ProverProof<Pallas>> for ProverProofTS {
    fn from(value: &ProverProof<Pallas>) -> Self {
        let ProverProof {
            evals,
            prev_challenges,
            commitments,
            ..
        } = value;

        ProverProofTS {
            evals: evals.clone(),
            prev_challenges: prev_challenges
                .iter()
                .map(RecursionChallengeTS::from)
                .collect(),
            commitments: ProverCommitmentsTS::from(commitments),
        }
    }
}
