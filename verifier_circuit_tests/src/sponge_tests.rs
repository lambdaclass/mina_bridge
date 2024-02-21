#[cfg(test)]
mod tests {
    use ark_ec::AffineCurve;
    use kimchi::{
        curve::KimchiCurve,
        mina_curves::pasta::{Fq, Pallas, PallasParameters},
        mina_poseidon::{
            constants::PlonkSpongeConstantsKimchi,
            sponge::{DefaultFqSponge, DefaultFrSponge},
            FqSponge,
        },
        proof::PointEvaluations,
    };
    use num_bigint::BigUint;
    use num_traits::Num;

    type PallasScalar = <Pallas as AffineCurve>::ScalarField;
    type PallasPointEvals = PointEvaluations<Vec<PallasScalar>>;

    type SpongeParams = PlonkSpongeConstantsKimchi;
    type BaseSponge = DefaultFqSponge<PallasParameters, SpongeParams>;
    type ScalarSponge = DefaultFrSponge<Fq, SpongeParams>;

    fn scalar_from_hex(hex: &str) -> PallasScalar {
        PallasScalar::from(BigUint::from_str_radix(hex, 16).unwrap())
    }

    #[test]
    fn test_absorb_digest_scalar() {
        let mut sponge = BaseSponge::new(Pallas::other_curve_sponge_params());
        let input = PallasScalar::from(42);
        sponge.absorb_fr(&[input]);
        let digest = sponge.digest();

        assert_eq!(
            digest,
            scalar_from_hex("176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500")
        );
    }
}
