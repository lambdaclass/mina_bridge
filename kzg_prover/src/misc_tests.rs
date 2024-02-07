#[cfg(test)]
mod test {
    use ark_ec::short_weierstrass_jacobian::GroupAffine;
    use kimchi::{
        curve::KimchiCurve,
        keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
        plonk_sponge::FrSponge,
        proof::ProverProof,
    };
    use mina_poseidon::sponge::ScalarChallenge;
    use num::BigUint;
    use num_traits::Num;
    use poly_commitment::pairing_proof::PairingProof;

    type BaseField = ark_bn254::Fq;
    type ScalarField = ark_bn254::Fr;
    type G1 = GroupAffine<ark_bn254::g1::Parameters>;

    type KeccakFqSponge = Keccak256FqSponge<BaseField, G1, ScalarField>;
    type KeccakFrSponge = Keccak256FrSponge<ScalarField>;

    type KZGProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;

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

    #[test]
    fn test_absorb_evaluations() {
        let prover_proof_serialized = include_bytes!("../test_data/prover_proof.mpk");
        let prover_proof: ProverProof<G1, KZGProof> =
            rmp_serde::from_slice(prover_proof_serialized).unwrap();

        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        sponge.absorb_evaluations(&prover_proof.evals);
        println!("evals.z: {}", prover_proof.evals.z.zeta[0]);
        println!("ft_eval1: {}", prover_proof.ft_eval1);
        panic!();
        assert_eq!(
            sponge.challenge().0,
            scalar_from_hex("0000000000000000000000000000000000DC56216206DF842F824D14A6D87024"),
        );
    }
}
