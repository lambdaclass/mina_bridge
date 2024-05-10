use std::sync::Arc;

use kimchi::circuits::constraints::ConstraintSystem;
use kimchi::circuits::gate::CircuitGate;
use kimchi::circuits::polynomials::range_check;
use kimchi::circuits::wires::Wire;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::{Fp, VestaParameters};
use kimchi::mina_poseidon::constants::PlonkSpongeConstantsKimchi;
use kimchi::mina_poseidon::sponge::{DefaultFqSponge, DefaultFrSponge};
use kimchi::poly_commitment::commitment::CommitmentCurve;
use kimchi::proof::ProverProof;
use kimchi::prover_index::ProverIndex;
use kimchi::verifier::verify;
use kimchi::{
    curve::KimchiCurve,
    mina_curves::pasta::Vesta,
    poly_commitment::{evaluation_proof::OpeningProof, srs::SRS},
    verifier_index::VerifierIndex,
};

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<VestaParameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fp, SpongeParams>;

type Curve = Vesta;
type ScalarField = Fp;

pub fn kimchi_verify(
    proof: &ProverProof<Curve, OpeningProof<Curve>>,
    verifier_index: &VerifierIndex<Curve, OpeningProof<Curve>>,
    group_map: <Curve as CommitmentCurve>::Map,
) -> bool {
    verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
        &group_map,
        verifier_index,
        proof,
        &Vec::new(),
    )
    .is_ok()
}

pub fn generate_test_proof() -> (
    ProverProof<Curve, OpeningProof<Curve>>,
    VerifierIndex<Curve, OpeningProof<Curve>>,
) {
    // Create range-check gadget
    let (mut next_row, mut gates) = CircuitGate::<ScalarField>::create_multi_range_check(0);

    // Create witness
    let witness = range_check::witness::create_multi::<ScalarField>(
        ScalarField::from(1),
        ScalarField::from(1),
        ScalarField::from(1),
    );

    // Temporary workaround for lookup-table/domain-size issue
    for _ in 0..(1 << 13) {
        gates.push(CircuitGate::zero(Wire::for_row(next_row)));
        next_row += 1;
    }
    // Create constraint system
    let cs = ConstraintSystem::<ScalarField>::create(gates)
        //.lookup(vec![range_check::gadget::lookup_table()])
        .build()
        .unwrap();

    let mut srs = SRS::create_trusted_setup(ScalarField::from(42), cs.gates.len());
    srs.add_lagrange_basis(cs.domain.d1);

    let (_endo_q, endo_r) = Curve::endos();
    let index =
        ProverIndex::<Curve, OpeningProof<Curve>>::create(cs, *endo_r, Arc::new(srs.clone()));

    let group_map = <Curve as CommitmentCurve>::Map::setup();
    let proof = ProverProof::create_recursive::<BaseSponge, ScalarSponge>(
        &group_map,
        witness,
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();

    // Verify
    assert!(
        verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
            &group_map,
            &index.verifier_index(),
            &proof,
            &Vec::new()
        )
        .is_ok(),
        "Generated test proof isn't valid."
    );

    (proof, index.verifier_index())
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_generate_proof() {
        generate_test_proof();
    }
}
