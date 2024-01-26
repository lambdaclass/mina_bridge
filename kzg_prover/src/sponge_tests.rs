#[cfg(test)]
mod test {
    use ark_ec::short_weierstrass_jacobian::GroupAffine;
    use kimchi::{
        curve::KimchiCurve,
        keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
        plonk_sponge::FrSponge,
    };

    type BaseField = ark_bn254::Fq;
    type ScalarField = ark_bn254::Fr;
    type G1 = GroupAffine<ark_bn254::g1::Parameters>;

    type KeccakFqSponge = Keccak256FqSponge<BaseField, G1, ScalarField>;
    type KeccakFrSponge = Keccak256FrSponge<ScalarField>;

    #[test]
    fn test_absorb_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let input = ScalarField::from(42);
        sponge.absorb(&input);

        println!("{}", sponge.digest());
        panic!();
    }
}
