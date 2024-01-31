#[cfg(test)]
mod test {
    use ark_ec::short_weierstrass_jacobian::GroupAffine;
    use kimchi::curve::KimchiCurve;
    use mina_poseidon::sponge::ScalarChallenge;
    use num::BigUint;
    use num_traits::Num;

    type BaseField = ark_bn254::Fq;
    type ScalarField = ark_bn254::Fr;
    type G1 = GroupAffine<ark_bn254::g1::Parameters>;

    fn scalar_from_hex(hex: &str) -> ScalarField {
        ScalarField::from(BigUint::from_str_radix(hex, 16).unwrap())
    }

    #[test]
    fn test_scalar_challenge_to_field() {
        let chal = ScalarChallenge(ScalarField::from(42));
        let (_, endo_r) = G1::endos();
        assert_eq!(
            chal.to_field(endo_r),
            scalar_from_hex("1B98C45C863AD2A1F4EB90EFBC8F1104AF5534B239720D63ECB7156E9347F622")
        );
    }
}
