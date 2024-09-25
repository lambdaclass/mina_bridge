/// Sends Mina proofs to AlignedLayer.
pub mod aligned;
/// Interacts with the bridge's smart contracts on Ethereum.
pub mod eth;
/// Interacts with a Mina node for requesting proofs and data.
pub mod mina;
/// Mina Proof of State/Account definitions and (de)serialization.
pub mod proof;
/// High level abstractions for the bridge.
pub mod sdk;
/// Solidity-friendly data structures and serialization.
pub mod sol;
/// Internal utils.
pub mod utils;
