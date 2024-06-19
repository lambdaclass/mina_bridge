use serde::Deserialize;

#[derive(Deserialize)]
pub struct StateProof {
    pub proof: Proof,
    pub statement: Statement,
}

#[derive(Deserialize)]
pub struct Proof {
    pub bulletproof: Bulletproof,
}

#[derive(Deserialize)]
pub struct Bulletproof {
    pub challenge_polynomial_commitment: Point,
    pub delta: Point,
    pub lr: [[Point; 2]; 15],
    pub z_1: String,
    pub z_2: String,
    pub commitments: Commitments,
    pub evaluations: Evaluations,
}

#[derive(Deserialize)]
pub struct Commitments {
    pub t_comm: [Point; 7],
    pub w_comm: [Point; 15],
    pub z_comm: Point,
}

#[derive(Deserialize)]
pub struct Evaluations {
    pub coefficients: [Point; 15],
    pub complete_add_selector: Point,
    pub emul_selector: Point,
    pub endomul_scalar_selector: Point,
    pub generic_selector: Point,
    pub mul_selector: Point,
    pub poseidon_selector: Point,
    pub s: [Point; 6],
    pub w: [Point; 15],
    pub z: Point,
    pub ft_eval1: String,
}

#[derive(Deserialize)]
pub struct Statement {
    pub messages_for_next_step_proof: MessagesForNextStepProof,
}

#[derive(Deserialize)]
pub struct MessagesForNextStepProof {
    pub challenge_polynomial_commitments: [Point; 2],
    pub old_bulletproof_challenges: [[BulletproofChallenge; 16]; 2],
    pub proof_state: ProofState,
}

#[derive(Deserialize)]
pub struct BulletproofChallenge {
    pub prechallenge: Prechallenge,
}

#[derive(Deserialize)]
pub struct Prechallenge {
    pub inner: Point,
}

#[derive(Deserialize)]
pub struct ProofState {
    pub deferred_values: DeferredValues,
    pub messages_for_next_wrap_proof: MessagesForNextWrapProof,
    pub sponge_digest_before_evaluations: [String; 4],
}

#[derive(Deserialize)]
pub struct DeferredValues {
    pub branch_data: BranchData,
    pub bulletproof_challenges: [BulletproofChallenge; 16],
    pub plonk: Plonk,
}

#[derive(Deserialize)]
pub struct BranchData {
    pub domain_log2: String,
    pub proofs_verified: [String; 1],
}

#[derive(Deserialize)]
pub struct Plonk {
    pub alpha: Prechallenge,
    pub beta: Point,
    pub feature_flags: FeatureFlags,
    pub gamma: Point,
    pub zeta: Prechallenge,
}

#[derive(Deserialize)]
pub struct FeatureFlags {
    pub foreign_field_add: bool,
    pub foreign_field_mul: bool,
    pub lookup: bool,
    pub range_check0: bool,
    pub range_check1: bool,
    pub rot: bool,
    pub runtime_tables: bool,
    pub xor: bool,
}

#[derive(Deserialize)]
pub struct MessagesForNextWrapProof {
    pub challenge_polynomial_commitment: Point,
    pub old_bulletproof_challenges: [[BulletproofChallenge; 16]; 2],
}

pub type Point = [String; 2];

pub fn parse(proof_json: &str) -> Result<StateProof, String> {
    serde_json::from_str(proof_json).map_err(|err| format!("Could not parse proof JSON: {err}"))
}
