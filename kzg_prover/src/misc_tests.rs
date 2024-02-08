#[cfg(test)]
mod test {
    use ark_ec::short_weierstrass_jacobian::GroupAffine;
    use kimchi::{
        circuits::polynomials::permutation::eval_vanishes_on_last_n_rows,
        curve::KimchiCurve,
        keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge},
        plonk_sponge::FrSponge,
        proof::ProverProof,
        verifier_index::VerifierIndex,
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
        let prover_proof_serialized = include_bytes!("../unit_test_data/prover_proof.mpk");
        let prover_proof: ProverProof<G1, KZGProof> =
            rmp_serde::from_slice(prover_proof_serialized).unwrap();

        let mut sponge = KeccakFrSponge::new(G1::sponge_params());
        sponge.absorb_evaluations(&prover_proof.evals);
        assert_eq!(
            sponge.challenge().0,
            scalar_from_hex("0000000000000000000000000000000000DC56216206DF842F824D14A6D87024"),
        );
    }

    #[test]
    fn test_eval_vanishing_poly_on_last_n_rows() {
        let verifier_index_serialized = include_bytes!("../unit_test_data/verifier_index.mpk");
        let verifier_index: VerifierIndex<G1, KZGProof> =
            rmp_serde::from_slice(verifier_index_serialized).unwrap();

        // hard-coded zeta is taken from executing the verifier in main.rs
        // the value doesn't matter, as long as it matches the analogous test in Solidity.
        let zeta =
            scalar_from_hex("1B427680FC915CB850FFF8701AD7E2D73B9F1349F713BFBE6B58E5D007988CD0");
        let permutation_vanishing_poly =
            eval_vanishes_on_last_n_rows(verifier_index.domain, verifier_index.zk_rows, zeta);
        assert_eq!(
            permutation_vanishing_poly,
            scalar_from_hex("2C5ACDAC911B82AE9F3E0D0D792DFEAC4638C8F482B99116BDC080527F5DEB7E")
        );
    }
}
