// Anvil related constants
pub const ANVIL_PRIVATE_KEY: &str =
    "2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"; // Anvil wallet 9
pub const ANVIL_CHAIN_ID: u64 = 31337;
pub const ANVIL_BATCHER_ADDR: &str = "ws://localhost:8080";
pub const ANVIL_BATCHER_ETH_ADDR: &str = "0x7969c5eD335650692Bc04293B07F5BF2e7A673C0";
pub const ANVIL_ETH_RPC_URL: &str = "http://localhost:8545";

// Holesky related constants
pub const HOLESKY_CHAIN_ID: u64 = 17000;

// Mina related constants
// TODO(gabrielbosio): These are temporary, we will fetch the tip from the Mina contract instead of using these hardcoded values.
pub const MINA_TIP_PROTOCOL_STATE: &str = "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";
pub const MINA_TIP_STATE_HASH_FIELD: &str =
    "26201757517054449641912404249424749469164718222967816857204695395894215860942";
pub const MINA_HASH_SIZE: usize = 32;

// Bridge related constants
pub const BRIDGE_DEVNET_ETH_ADDR: &str = "0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35";
pub const BRIDGE_HOLESKY_ETH_ADDR: &str = "0x9dD655fE21fA10FeD52C0DAD48Ac937517f1451A";

// Aligned related constants
pub const PROOF_GENERATOR_ADDR: &str = "0x66f9664f97F2b50F62D13eA064982f936dE76657";
pub const ALIGNED_SM_DEVNET_ETH_ADDR: &str = "0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8";
pub const ALIGNED_SM_HOLESKY_ETH_ADDR: &str = "0x0584313310bD52B77CF0b81b350Ca447B97Df5DF";
