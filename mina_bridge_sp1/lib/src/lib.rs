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
) -> bool {
    verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
        &<Curve as CommitmentCurve>::Map::setup(),
        verifier_index,
        proof,
        &Vec::new(),
    )
    .is_ok()
}

#[allow(clippy::type_complexity)]
pub fn generate_test_proof() -> (
    ProverProof<Curve, OpeningProof<Curve>>,
    VerifierIndex<Curve, OpeningProof<Curve>>,
    SRS<Curve>,
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

    (proof, index.verifier_index(), srs)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_generate_proof() {
        let (proof, verifier_index, srs) = generate_test_proof();
        println!("SRS size: {}", srs.g.len());
        for key in srs.lagrange_bases.keys() {
            println!("Lagrange bases size: {}", srs.lagrange_bases[key].len());
        }

        /*
            SRS and lagrange bases don't implement serde, so we need to
            pass them as inputs separately.
            In the test this has no effect but the code is there to reflect
            what is needed to do inside the SP1 script.

            ```rust
            srs.lagrange_bases = srs.lagrange_bases;
            verifier_index.srs = Arc::new(srs);
            ```
        */

        assert!(kimchi_verify(&proof, &verifier_index));
    }
}
