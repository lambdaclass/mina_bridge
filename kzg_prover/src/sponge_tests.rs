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
    use rmp_serde::encode::write;

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

    #[test]
    fn test_absorb_absorb_digest_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let inputs = [ScalarField::from(42), ScalarField::from(24)];
        sponge.absorb(&inputs[0]);
        sponge.absorb(&inputs[1]);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("00DB760B992492E99DAE648DBA78682EB78FAFF3B40E0DB291710EFCB8A7D0D3",)
        );
    }

    #[test]
    fn test_absorb_challenge_challenge_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let input = ScalarField::from(42);
        sponge.absorb(&input);
        let challenges = [sponge.challenge(), sponge.challenge()];

        assert_eq!(
            challenges[0].0,
            scalar_from_hex("0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D",)
        );
        assert_eq!(
            challenges[1].0,
            scalar_from_hex("0000000000000000000000000000000000964765235251D0E2EACFBC25925D55",)
        );
    }

    #[test]
    fn test_absorb_challenge_absorb_challenge_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        let inputs = [ScalarField::from(42), ScalarField::from(24)];

        sponge.absorb(&inputs[0]);
        let challenge = sponge.challenge();
        assert_eq!(
            challenge.0,
            scalar_from_hex("0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D",)
        );
        sponge.absorb(&inputs[1]);
        let challenge = sponge.challenge();
        assert_eq!(
            challenge.0,
            scalar_from_hex("0000000000000000000000000000000000D9E16B1DA42107514692CD8896E64F",)
        );
    }

    #[test]
    fn test_challenge_challenge_scalar() {
        let mut sponge = KeccakFrSponge::new(G1::sponge_params());

        let challenge = sponge.challenge();
        assert_eq!(
            challenge.0,
            scalar_from_hex("0000000000000000000000000000000000C5D2460186F7233C927E7DB2DCC703",)
        );
        let challenge = sponge.challenge();
        assert_eq!(
            challenge.0,
            scalar_from_hex("000000000000000000000000000000000010CA3EFF73EBEC87D2394FC58560AF",)
        );
    }
}
