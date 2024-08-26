use mina_p2p_messages::v2::{
    LedgerHash, MinaBaseProofStableV2, MinaStateProtocolStateValueStableV2, StateHash,
};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use crate::{proof::serialization::EVMSerialize, utils::constants::BRIDGE_TRANSITION_FRONTIER_LEN};

#[serde_as]
#[derive(Serialize, Deserialize)]
pub struct MinaStatePubInputs {
    #[serde_as(as = "EVMSerialize")]
    pub bridge_tip_state_hash: StateHash,
    #[serde_as(as = "[EVMSerialize; BRIDGE_TRANSITION_FRONTIER_LEN]")]
    pub candidate_chain_state_hashes: [StateHash; BRIDGE_TRANSITION_FRONTIER_LEN],
    #[serde_as(as = "[EVMSerialize; BRIDGE_TRANSITION_FRONTIER_LEN]")]
    pub candidate_chain_ledger_hashes: [LedgerHash; BRIDGE_TRANSITION_FRONTIER_LEN],
}

#[derive(Serialize, Deserialize)]
pub struct MinaStateProof {
    pub candidate_tip_proof: MinaBaseProofStableV2,
    pub candidate_tip_state: MinaStateProtocolStateValueStableV2,
    pub bridge_tip_state: MinaStateProtocolStateValueStableV2,
}
