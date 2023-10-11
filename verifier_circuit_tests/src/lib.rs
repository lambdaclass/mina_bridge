use ark_ec::AffineCurve;
use ark_ff::{One, PrimeField};
use ark_poly::{domain::EvaluationDomain, UVPolynomial};
use kimchi::{
    circuits::expr::{Linearization, PolishToken},
    curve::KimchiCurve,
    error::VerifyError,
    mina_curves::pasta::{Fq, Pallas, PallasParameters},
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    o1_utils::FieldHelpers,
    poly_commitment::{evaluation_proof::OpeningProof, OpenProof, PolyComm, SRS},
    proof::{
        LookupCommitments, PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof,
        RecursionChallenge,
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
pub fn check_proof_evals_len<G, OpeningProof>(
    proof: &ProverProof<G, OpeningProof>,
    expected_size: usize,
) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    let ProofEvaluations {
        public,
        w,
        z,
        s,
        coefficients,
        generic_selector,
        poseidon_selector,
        complete_add_selector,
        mul_selector,
        emul_selector,
        endomul_scalar_selector,
        range_check0_selector,
        range_check1_selector,
        foreign_field_add_selector,
        foreign_field_mul_selector,
        xor_selector,
        rot_selector,
        lookup_aggregation,
        lookup_table,
        lookup_sorted,
        runtime_lookup_table,
        runtime_lookup_table_selector,
        xor_lookup_selector,
        lookup_gate_lookup_selector,
        range_check_lookup_selector,
        foreign_field_mul_lookup_selector,
    } = &proof.evals;

    let check_eval_len =
        |eval: &PointEvaluations<Vec<_>>, str: &'static str| -> Result<(), VerifyError> {
            if eval.zeta.len() != expected_size {
                Err(VerifyError::IncorrectEvaluationsLength(
                    expected_size,
                    eval.zeta.len(),
                    str,
                ))
            } else if eval.zeta_omega.len() != expected_size {
                Err(VerifyError::IncorrectEvaluationsLength(
                    expected_size,
                    eval.zeta_omega.len(),
                    str,
                ))
            } else {
                Ok(())
            }
        };

    if let Some(public) = public {
        check_eval_len(public, "public input")?;
    }

    for w_i in w {
        check_eval_len(w_i, "witness")?;
    }
    check_eval_len(z, "permutation accumulator")?;
    for s_i in s {
        check_eval_len(s_i, "permutation shifts")?;
    }
    for coeff in coefficients {
        check_eval_len(coeff, "coefficients")?;
    }

    // Lookup evaluations
    for sorted in lookup_sorted.iter().flatten() {
        check_eval_len(sorted, "lookup sorted")?
    }

    if let Some(lookup_aggregation) = lookup_aggregation {
        check_eval_len(lookup_aggregation, "lookup aggregation")?;
    }
    if let Some(lookup_table) = lookup_table {
        check_eval_len(lookup_table, "lookup table")?;
    }
    if let Some(runtime_lookup_table) = runtime_lookup_table {
        check_eval_len(runtime_lookup_table, "runtime lookup table")?;
    }

    check_eval_len(generic_selector, "generic selector")?;
    check_eval_len(poseidon_selector, "poseidon selector")?;
    check_eval_len(complete_add_selector, "complete add selector")?;
    check_eval_len(mul_selector, "mul selector")?;
    check_eval_len(emul_selector, "endomul selector")?;
    check_eval_len(endomul_scalar_selector, "endomul scalar selector")?;

    // Optional gates

    if let Some(range_check0_selector) = range_check0_selector {
        check_eval_len(range_check0_selector, "range check 0 selector")?
    }
    if let Some(range_check1_selector) = range_check1_selector {
        check_eval_len(range_check1_selector, "range check 1 selector")?
    }
    if let Some(foreign_field_add_selector) = foreign_field_add_selector {
        check_eval_len(foreign_field_add_selector, "foreign field add selector")?
    }
    if let Some(foreign_field_mul_selector) = foreign_field_mul_selector {
        check_eval_len(foreign_field_mul_selector, "foreign field mul selector")?
    }
    if let Some(xor_selector) = xor_selector {
        check_eval_len(xor_selector, "xor selector")?
    }
    if let Some(rot_selector) = rot_selector {
        check_eval_len(rot_selector, "rot selector")?
    }

    // Lookup selectors

    if let Some(runtime_lookup_table_selector) = runtime_lookup_table_selector {
        check_eval_len(
            runtime_lookup_table_selector,
            "runtime lookup table selector",
        )?
    }
    if let Some(xor_lookup_selector) = xor_lookup_selector {
        check_eval_len(xor_lookup_selector, "xor lookup selector")?
    }
    if let Some(lookup_gate_lookup_selector) = lookup_gate_lookup_selector {
        check_eval_len(lookup_gate_lookup_selector, "lookup gate lookup selector")?
    }
    if let Some(range_check_lookup_selector) = range_check_lookup_selector {
        check_eval_len(range_check_lookup_selector, "range check lookup selector")?
    }
    if let Some(foreign_field_mul_lookup_selector) = foreign_field_mul_lookup_selector {
        check_eval_len(
            foreign_field_mul_lookup_selector,
            "foreign field mul lookup selector",
        )?
    }

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
pub fn to_batch_step1<G, OpeningProof: OpenProof<G>>(
    proof: &ProverProof<G, OpeningProof>,
    verifier_index: &VerifierIndex<G, OpeningProof>,
) -> Result<(), VerifyError>
where
    G: KimchiCurve,
    G::BaseField: PrimeField,
{
    let chunk_size = {
        let d1_size = verifier_index.domain.size();
        if d1_size < verifier_index.max_poly_size {
            1
        } else {
            d1_size / verifier_index.max_poly_size
        }
    };
    println!("to_batch(), step 1: Commit to the negated public input polynomial.");
    check_proof_evals_len(proof, chunk_size)?;
    Ok(())
}

/// Execute step 2 of partial verification
pub fn to_batch_step2<G, OpeningProof: OpenProof<G>>(
    verifier_index: &VerifierIndex<G, OpeningProof>,
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
            .get_lagrange_basis(verifier_index.domain.size())
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
    zk_rows: u64,

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
    permutation_vanishing_polynomial_m: Vec<String>,
    w: String,
    endo: String,
    linearization: Linearization<Vec<PolishToken<String>>>,
}

fn token_to_hex(value: &PolishToken<PallasScalar>) -> PolishToken<String> {
    // Only the Literal variant needs to be converted to another specialization,
    // but Rust doesn't seem to allow me to put an arm to match any other variant and convert
    // its generic. It doesn't "know" that all other variants don't care about the
    // generic and can be converted directly. This is why I specified every variant.
    match value {
        PolishToken::Alpha => PolishToken::Alpha,
        PolishToken::Beta => PolishToken::Beta,
        PolishToken::Gamma => PolishToken::Gamma,
        PolishToken::JointCombiner => PolishToken::JointCombiner,
        PolishToken::EndoCoefficient => PolishToken::EndoCoefficient,
        PolishToken::Mds { row, col } => PolishToken::Mds {
            row: *row,
            col: *col,
        },
        PolishToken::Literal(elem) => PolishToken::Literal(elem.to_hex()),
        PolishToken::Cell(x) => PolishToken::Cell(*x),
        PolishToken::Dup => PolishToken::Dup,
        PolishToken::Pow(x) => PolishToken::Pow(*x),
        PolishToken::Add => PolishToken::Add,
        PolishToken::Mul => PolishToken::Mul,
        PolishToken::Sub => PolishToken::Sub,
        PolishToken::VanishesOnZeroKnowledgeAndPreviousRows => {
            PolishToken::VanishesOnZeroKnowledgeAndPreviousRows
        }
        PolishToken::UnnormalizedLagrangeBasis(x) => PolishToken::UnnormalizedLagrangeBasis(*x),
        PolishToken::Store => PolishToken::Store,
        PolishToken::Load(x) => PolishToken::Load(*x),
        PolishToken::SkipIf(x, y) => PolishToken::SkipIf(*x, *y),
        PolishToken::SkipIfNot(x, y) => PolishToken::SkipIfNot(*x, *y),
    }
}

impl From<&VerifierIndex<Pallas, OpeningProof<Pallas>>> for VerifierIndexTS {
    fn from(value: &VerifierIndex<Pallas, OpeningProof<Pallas>>) -> Self {
        let VerifierIndex {
            domain,
            public,
            max_poly_size,
            zk_rows,
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
            permutation_vanishing_polynomial_m,
            w,
            endo,
            linearization,
            ..
        } = value;

        let linearization = {
            let constant_term = linearization
                .constant_term
                .iter()
                .map(token_to_hex)
                .collect::<Vec<_>>();
            let index_terms = linearization
                .index_terms
                .iter()
                .map(|(col, tok)| (*col, tok.iter().map(token_to_hex).collect::<Vec<_>>()))
                .collect::<Vec<_>>();
            Linearization {
                constant_term,
                index_terms,
            }
        };

        VerifierIndexTS {
            domain_size: domain.size(),
            domain_gen: domain.group_gen.to_hex(),
            public_size: *public,
            max_poly_size: *max_poly_size,
            zk_rows: *zk_rows,
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
            permutation_vanishing_polynomial_m: permutation_vanishing_polynomial_m
                .get()
                .unwrap()
                .coeffs()
                .iter()
                .map(|e| e.to_hex())
                .collect::<Vec<_>>(),
            w: w.get().unwrap().to_hex(),
            endo: endo.to_hex(),
            linearization,
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
    ft_eval1: String,
}

impl From<&ProverProof<Pallas, OpeningProof<Pallas>>> for ProverProofTS {
    fn from(value: &ProverProof<Pallas, OpeningProof<Pallas>>) -> Self {
        let ProverProof {
            evals,
            prev_challenges,
            commitments,
            ft_eval1,
            ..
        } = value;

        ProverProofTS {
            evals: evals.clone(),
            prev_challenges: prev_challenges
                .iter()
                .map(RecursionChallengeTS::from)
                .collect(),
            commitments: ProverCommitmentsTS::from(commitments),
            ft_eval1: ft_eval1.to_hex(),
        }
    }
}
