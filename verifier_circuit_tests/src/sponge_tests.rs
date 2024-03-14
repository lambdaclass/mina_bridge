#[cfg(test)]
mod tests {
    use ark_ec::AffineCurve;
    use kimchi::{
        curve::KimchiCurve,
        mina_curves::pasta::{Pallas, PallasParameters},
        mina_poseidon::{
            constants::PlonkSpongeConstantsKimchi,
            poseidon::Sponge,
            sponge::{DefaultFqSponge, DefaultFrSponge},
            FqSponge,
        },
        plonk_sponge::FrSponge,
    };
    use num_bigint::BigUint;
    use num_traits::Num;

    type PallasScalar = <Pallas as AffineCurve>::ScalarField;
    type PallasBase = <Pallas as AffineCurve>::BaseField;

    type SpongeParams = PlonkSpongeConstantsKimchi;
    type FqTestSponge = DefaultFqSponge<PallasParameters, SpongeParams>;
    type FrTestSponge = DefaultFrSponge<PallasScalar, SpongeParams>;

    fn scalar_from_hex(hex: &str) -> PallasScalar {
        PallasScalar::from(BigUint::from_str_radix(hex, 16).unwrap())
    }
    fn base_from_hex(hex: &str) -> PallasBase {
        PallasBase::from(BigUint::from_str_radix(hex, 16).unwrap())
    }

    #[test]
    fn test_squeeze_internal() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        let digest = sponge.sponge.squeeze();

        assert_eq!(
            digest,
            base_from_hex("2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8")
        );
    }

    #[test]
    fn test_fr_squeeze_internal() {
        let mut sponge = FrTestSponge::new(Pallas::sponge_params());
        let digest = sponge.sponge.squeeze();

        assert_eq!(
            digest,
            scalar_from_hex("3A3374A061464EC0AAC7E0FF04346926C579D542F9D205A670CE4C18C004E5C1")
        );
    }

    #[test]
    fn test_absorb_squeeze_internal() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        sponge.sponge.absorb(&[base_from_hex(
            "36FB00AD544E073B92B4E700D9C49DE6FC93536CAE0C612C18FBE5F6D8E8EEF2",
        )]);
        let digest = sponge.sponge.squeeze();

        assert_eq!(
            digest,
            base_from_hex("3D4F050775295C04619E72176746AD1290D391D73FF4955933F9075CF69259FB")
        );
    }

    #[test]
    fn test_fr_absorb_squeeze_internal() {
        let mut sponge = FrTestSponge::new(Pallas::sponge_params());
        sponge.sponge.absorb(&[scalar_from_hex("42")]);
        let digest = sponge.sponge.squeeze();

        assert_eq!(
            digest,
            scalar_from_hex("393DDD2CE7E8CC8F929F9D70F25257B924A085542E3C039DD8B04BEA0E885DCB")
        );
    }

    #[test]
    fn test_digest_scalar() {
        let sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8")
        );
    }

    #[test]
    fn test_absorb_digest_scalar() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        let input = PallasScalar::from(42);
        sponge.absorb_fr(&[input]);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500")
        );
    }

    #[test]
    fn test_fr_absorb_digest_scalar() {
        let mut sponge = FrTestSponge::new(Pallas::sponge_params());
        let input = PallasScalar::from(42);
        sponge.absorb(&input);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("15D31425CD40BB52E708D4E85DF366F62A9194688826F6555035DC65497D5B26")
        );
    }

    #[test]
    fn test_absorb_challenge() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        let input = PallasScalar::from(42);
        sponge.absorb_fr(&[input]);
        let challenge = sponge.challenge();

        assert_eq!(
            challenge,
            scalar_from_hex("00000000000000000000000000000000E5D06DD18817A7A8C11794A818965500")
        );
    }

    #[test]
    fn test_absorb_challenge_fq() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
        let input = PallasScalar::from(42);
        sponge.absorb_fr(&[input]);
        let challenge = sponge.challenge_fq();

        assert_eq!(
            challenge,
            base_from_hex("176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500")
        );
    }
}
