use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};

// BN254
pub type BaseSpongeBN254 = DefaultFqSponge<ark_bn254::g1::Parameters, PlonkSpongeConstantsKimchi>;
pub type BN254 = GroupAffine<ark_bn254::g1::Parameters>;
