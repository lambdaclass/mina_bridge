use account_proof::{MinaAccountProof, MinaAccountPubInputs};
use state_proof::{MinaStateProof, MinaStatePubInputs};

/// Mina Proof of Account definition.
pub mod account_proof;
/// Mina Proof of State definition.
pub mod state_proof;

// TODO(xqft): we should fix this lint instead
#[allow(clippy::large_enum_variant)]
pub enum MinaProof {
    State((MinaStateProof, MinaStatePubInputs)),
    Account((MinaAccountProof, MinaAccountPubInputs)),
}

/// Proof (de)serialization.
pub mod serialization;
