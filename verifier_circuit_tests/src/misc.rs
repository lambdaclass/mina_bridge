use ark_ec::AffineCurve;
use ark_poly::{domain::EvaluationDomain, UVPolynomial};
use kimchi::{
    circuits::expr::{Linearization, PolishToken},
    mina_curves::pasta::{Fq, Pallas, PallasParameters},
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    o1_utils::FieldHelpers,
    poly_commitment::{evaluation_proof::OpeningProof, PolyComm},
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

/// Useful for serializing into JSON and importing in Typescript tests.
#[derive(Serialize, Debug)]
pub struct UncompressedPoint {
    pub x: String,
    pub y: String,
}

impl From<&Pallas> for UncompressedPoint {
    fn from(value: &Pallas) -> Self {
        UncompressedPoint {
            x: value.x.to_biguint().to_string(),
            y: value.y.to_biguint().to_string(),
        }
    }
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
                .map(UncompressedPoint::from)
                .collect(),
            shifted: value.shifted.map(|s| UncompressedPoint::from(&s)),
        }
    }
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

    range_check0_comm: Option<UncompressedPolyComm>,

    range_check1_comm: Option<UncompressedPolyComm>,

    foreign_field_add_comm: Option<UncompressedPolyComm>,

    foreign_field_mul_comm: Option<UncompressedPolyComm>,

    xor_comm: Option<UncompressedPolyComm>,

    rot_comm: Option<UncompressedPolyComm>,

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
            range_check0_comm,
            range_check1_comm,
            foreign_field_add_comm,
            foreign_field_mul_comm,
            xor_comm,
            rot_comm,
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
            range_check0_comm: range_check0_comm.as_ref().map(UncompressedPolyComm::from),
            range_check1_comm: range_check1_comm.as_ref().map(UncompressedPolyComm::from),
            foreign_field_add_comm: foreign_field_add_comm.as_ref().map(UncompressedPolyComm::from),
            foreign_field_mul_comm: foreign_field_mul_comm.as_ref().map(UncompressedPolyComm::from),
            xor_comm: xor_comm.as_ref().map(UncompressedPolyComm::from),
            rot_comm: rot_comm.as_ref().map(UncompressedPolyComm::from),
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

#[derive(Serialize)]
pub struct OpeningProofTS {
    lr: Vec<(UncompressedPoint, UncompressedPoint)>,
    delta: UncompressedPoint,
    z1: String,
    z2: String,
    sg: UncompressedPoint,
}

impl From<&OpeningProof<Pallas>> for OpeningProofTS {
    fn from(value: &OpeningProof<Pallas>) -> Self {
        let OpeningProof {
            lr,
            delta,
            z1,
            z2,
            sg,
        } = value;

        let lr = lr.iter().map(|(g1, g2)| (g1.into(), g2.into())).collect();
        let delta = delta.into();
        let z1 = z1.to_hex();
        let z2 = z2.to_hex();
        let sg = sg.into();

        OpeningProofTS {
            lr,
            delta,
            z1,
            z2,
            sg,
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
    proof: OpeningProofTS,
}

impl From<&ProverProof<Pallas, OpeningProof<Pallas>>> for ProverProofTS {
    fn from(value: &ProverProof<Pallas, OpeningProof<Pallas>>) -> Self {
        let ProverProof {
            evals,
            prev_challenges,
            commitments,
            ft_eval1,
            proof,
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
            proof: proof.into(),
        }
    }
}
