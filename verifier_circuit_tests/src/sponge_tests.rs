#[cfg(test)]
mod tests {
    use ark_ec::AffineCurve;
    use kimchi::{
        curve::KimchiCurve,
        mina_curves::pasta::{Pallas, PallasParameters},
        mina_poseidon::{
            constants::PlonkSpongeConstantsKimchi, poseidon::Sponge, sponge::DefaultFqSponge,
            FqSponge,
        },
    };
    use num_bigint::BigUint;
    use num_traits::Num;

    type PallasScalar = <Pallas as AffineCurve>::ScalarField;
    type PallasBase = <Pallas as AffineCurve>::BaseField;

    type SpongeParams = PlonkSpongeConstantsKimchi;
    type FqTestSponge = DefaultFqSponge<PallasParameters, SpongeParams>;

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
    fn test_digest_scalar() {
        let mut sponge = FqTestSponge::new(Pallas::other_curve_sponge_params());
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
}
