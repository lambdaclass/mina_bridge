/// Service that polls a Mina node for a state proof and serializes it in an Aligned-friendly
/// format.
pub mod mina_polling_service;

/// Service that sends a Mina proof to Aligned and awaits a response. Returns the verification
/// data.
pub mod aligned_polling_service;

/// Utility for updating the bridge's smart contract with a new, verified state.
pub mod smart_contract_utility;

/// Internal utils.
pub mod utils;

/// Mina Proof of State/Account definitions and (de)serialization.
pub mod proof;

/// Solidity-friendly data structures and serialization.
pub mod sol;
