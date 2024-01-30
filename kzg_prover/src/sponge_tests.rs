#[cfg(test)]
mod test {
    use ark_ec::{short_weierstrass_jacobian::GroupAffine, AffineCurve};
    use kimchi::{
        curve::KimchiCurve,
        keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
        plonk_sponge::FrSponge,
    };
    use mina_poseidon::FqSponge;
    use num::BigUint;
    use num_traits::Num;
    use poly_commitment::PolyComm;

    type BaseField = ark_bn254::Fq;
    type ScalarField = ark_bn254::Fr;
    type G1 = GroupAffine<ark_bn254::g1::Parameters>;

    type KeccakFqSponge = Keccak256FqSponge<BaseField, G1, ScalarField>;
    type KeccakFrSponge = Keccak256FrSponge<ScalarField>;

    fn scalar_from_hex(hex: &str) -> ScalarField {
        ScalarField::from(BigUint::from_str_radix(hex, 16).unwrap())
    }

    #[test]
    fn test_absorb_digest_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let input = ScalarField::from(42);
        sponge.absorb(&input);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("00BECED09521047D05B8960B7E7BCC1D1292CF3E4B2A6B63F48335CBDE5F7545",)
        );
    }

    #[test]
    fn test_absorb_challenge_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let input = ScalarField::from(42);
        sponge.absorb(&input);
        let digest = sponge.challenge().0;

        assert_eq!(
            digest,
            scalar_from_hex("0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D",)
        );
    }

    #[test]
    fn test_absorb_digest_g() {
        let mut sponge = KeccakFqSponge::new(G1::other_curve_sponge_params());
        let input = vec![G1::prime_subgroup_generator()];
        sponge.absorb_g(&input);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("00E90B7BCEB6E7DF5418FB78D8EE546E97C83A08BBCCC01A0644D599CCD2A7C2",)
        );
    }
}
