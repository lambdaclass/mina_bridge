use ark_ec::AffineCurve;
use ark_ff::{One, PrimeField};
use ark_poly::domain::EvaluationDomain;
use kimchi::{
    alphas::Alphas,
    circuits::expr::PolishToken,
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

/// `PallasScalar` is an external type and it doesn't implement `Serialize`. This is a wapper for
/// implementing a serialize function to it.
pub struct SerializablePallasScalar(PallasScalar);

impl Serialize for SerializablePallasScalar {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.0.to_string())
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

/// A helper type for serializing the VerifierIndex data used in the verifier circuit.
#[derive(Serialize, Debug)]
pub struct VerifierIndexTS {
    //srs: SRS<Pallas>, // excluded because it already is serialized in typescript
    domain_size: usize,
    domain_gen: String,
    public_size: usize,
    max_poly_size: usize,

    sigma_comm: Vec<UncompressedPolyComm>, // of size PERMUTS
    coefficients_comm: Vec<UncompressedPolyComm>, // of size COLUMNS
    generic_comm: UncompressedPolyComm,

    psm_comm: UncompressedPolyComm,

    complete_add_comm: UncompressedPolyComm,
    mul_comm: UncompressedPolyComm,
    emul_comm: UncompressedPolyComm,
    endomul_scalar_comm: UncompressedPolyComm,

    //powers_of_alpha: Alphas<String>,
    shift: Vec<String>,
    zkpm: Vec<String>,
    w: String,
    endo: String,
    linear_constant_term: Vec<PolishToken<String>>,
}

impl From<&VerifierIndex<Pallas>> for VerifierIndexTS {
    fn from(value: &VerifierIndex<Pallas>) -> Self {
        let VerifierIndex {
            domain,
            public,
            max_poly_size,
            sigma_comm,
            coefficients_comm,
            generic_comm,
            psm_comm,
            complete_add_comm,
            mul_comm,
            emul_comm,
            endomul_scalar_comm,
            //powers_of_alpha,
            shift,
            zkpm,
            w,
            endo,
            linearization,
            ..
        } = value;

        let linear_constant_term = {
            linearization
                .constant_term
                .iter()
                .map(|token| {
                    // Only the Literal variant needs to be converted to another specialization,
                    // but Rust doesn't seem to allow me to put an arm to match any other variant and convert
                    // its generic. It doesn't "know" that all other variants don't care about the
                    // generic and can be converted directly. This is why I specified every variant.
                    match token {
                        PolishToken::Alpha => PolishToken::Alpha,
                        PolishToken::Beta => PolishToken::Beta,
                        PolishToken::Gamma => PolishToken::Gamma,
                        PolishToken::JointCombiner => PolishToken::JointCombiner,
                        PolishToken::EndoCoefficient => PolishToken::EndoCoefficient,
                        PolishToken::Mds { row, col } => PolishToken::Mds { row: *row, col: *col },
                        PolishToken::Literal(elem) => PolishToken::Literal(elem.to_hex()),
                        PolishToken::Cell(x) => PolishToken::Cell(*x),
                        PolishToken::Dup => PolishToken::Dup,
                        PolishToken::Pow(x) => PolishToken::Pow(*x),
                        PolishToken::Add => PolishToken::Add,
                        PolishToken::Mul => PolishToken::Mul,
                        PolishToken::Sub => PolishToken::Sub,
                        PolishToken::VanishesOnLast4Rows => PolishToken::VanishesOnLast4Rows,
                        PolishToken::UnnormalizedLagrangeBasis(x) => PolishToken::UnnormalizedLagrangeBasis(*x),
                        PolishToken::Store => PolishToken::Store,
                        PolishToken::Load(x) => PolishToken::Load(*x),
                        PolishToken::SkipIf(x, y) => PolishToken::SkipIf(*x, *y),
                        PolishToken::SkipIfNot(x, y) => PolishToken::SkipIfNot(*x, *y),
                    }
                })
                .collect::<Vec<_>>()
        };

        VerifierIndexTS {
            domain_size: domain.size(),
            domain_gen: domain.group_gen.to_hex(),
            public_size: *public,
            max_poly_size: *max_poly_size,
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
            //powers_of_alpha,
            shift: shift.iter().map(|e| e.to_hex()).collect::<Vec<_>>(),
            zkpm: zkpm
                .get()
                .unwrap()
                .coeffs
                .iter()
                .map(|e| e.to_hex())
                .collect::<Vec<_>>(),
            w: w.get().unwrap().to_hex(),
            endo: endo.to_hex(),
            linear_constant_term,
        }
    }
}

/// A helper type for serializing the ProverCommitments data used in the verifier circuit. This
/// will be part of `ProverProofTS`.
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

/// A helper type for serializing the RecursionChallenge data used in the verifier circuit.
/// This will be part of `ProverProofTS`.
#[derive(Serialize)]
pub struct RecursionChallengeTS {
    chals: Vec<SerializablePallasScalar>,
    comm: UncompressedPolyComm,
}

impl From<&RecursionChallenge<Pallas>> for RecursionChallengeTS {
    fn from(value: &RecursionChallenge<Pallas>) -> Self {
        let RecursionChallenge { chals, comm } = value;

        RecursionChallengeTS {
            chals: chals.iter().map(|s| SerializablePallasScalar(*s)).collect(),
            comm: UncompressedPolyComm::from(comm),
        }
    }
}

/// A helper type for serializing the proof data used in the verifier circuit.
#[derive(Serialize)]
pub struct ProverProofTS {
    evals: ProofEvaluations<PallasPointEvals>, // a helper for ProofEvaluattions is not needed
    // because it can be correctly deserialized in TS
    // as it is now.
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
