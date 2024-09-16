use mina_p2p_messages::v2::{
    LedgerHash, MinaBaseProofStableV2, MinaStateProtocolStateValueStableV2, StateHash,
};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use crate::{sol::serialization::SolSerialize, utils::constants::BRIDGE_TRANSITION_FRONTIER_LEN};

#[serde_as]
#[derive(Serialize, Deserialize, Clone)]
pub struct MinaStatePubInputs {
    /// The hash of the bridge's transition frontier tip state. Used for making sure that we're
    /// checking if a candidate tip is better than the latest bridged tip.
    #[serde_as(as = "SolSerialize")]
    pub bridge_tip_state_hash: StateHash,
    /// The state hashes of the candidate chain.
    #[serde_as(as = "[SolSerialize; BRIDGE_TRANSITION_FRONTIER_LEN]")]
    pub candidate_chain_state_hashes: [StateHash; BRIDGE_TRANSITION_FRONTIER_LEN],
    /// The ledger hashes of the candidate chain. The ledger hashes are the root of a Merkle tree
    /// where the leafs are Mina account hashes. Used for account verification.
    #[serde_as(as = "[SolSerialize; BRIDGE_TRANSITION_FRONTIER_LEN]")]
    pub candidate_chain_ledger_hashes: [LedgerHash; BRIDGE_TRANSITION_FRONTIER_LEN],
}

#[derive(Serialize, Deserialize)]
pub struct MinaStateProof {
    /// The state proof of the tip state (latest state of the chain, or "transition frontier"). If
    /// this state is valid, then all previous states are valid thanks to Pickles recursion.
    pub candidate_tip_proof: MinaBaseProofStableV2,
    /// The latest state of the candidate chain. Used for consensus checks needed to be done as
    /// part of state verification to ensure that the candidate tip is better than the bridged tip.
    /// We take an array of states to ensure that the root state (oldest state on the chain) is
    /// relatively (sufficiently) finalized.
    pub candidate_chain_states:
        [MinaStateProtocolStateValueStableV2; BRIDGE_TRANSITION_FRONTIER_LEN],
    /// The latest state of the previously bridged chain, the latter also called the bridge's
    /// transition frontier. Used for consensus checks needed to be done as part of state
    /// verification to ensure that the candidate tip is better than the bridged tip.
    pub bridge_tip_state: MinaStateProtocolStateValueStableV2,
}
