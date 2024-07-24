/// Service that polls a Mina node for a state proof and serializes it in an Aligned-friendly
/// format.
pub mod mina_polling_service;

/// Services that sends a Mina proof to Aligned, awaits a response and updates the Bridge's smart
/// contract.
pub mod aligned_polling_service;
