pub mod constraint_system;

use std::array;
use std::str::FromStr;
use std::sync::Arc;

use kimchi::circuits::gate::{CircuitGate, GateType};
use kimchi::circuits::wires::Wire;
use kimchi::curve::KimchiCurve;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::{Fp, Vesta, VestaParameters};
use kimchi::mina_poseidon::constants::PlonkSpongeConstantsKimchi;
use kimchi::mina_poseidon::sponge::{DefaultFqSponge, DefaultFrSponge};
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::poly_commitment::srs::SRS;
use kimchi::prover_index::ProverIndex;
use kimchi::{poly_commitment::commitment::CommitmentCurve, proof::ProverProof};

type BaseSponge = DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>;
type ScalarSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

fn main() {
    let cs_json = std::fs::read_to_string("./test_data/constraint_system.json").unwrap();
    let cs = constraint_system::ConstraintSystem::from(cs_json.as_str());
    let elem_list = cs.0;
    let gates: Vec<_> = elem_list
        .iter()
        .map(|gate| {
            let gate_type = if gate.r#type == "Generic" {
                GateType::Generic
            } else {
                GateType::Zero
            };
            let wires: [Wire; 7] = gate
                .wires
                .iter()
                .map(|wire| Wire::new(wire.row, wire.col))
                .collect::<Vec<_>>()
                .try_into()
                .unwrap();
            let coeffs: Vec<Fp> = gate
                .coeffs
                .iter()
                .map(|coeff| Fp::from_str(coeff).unwrap())
                .collect();
            CircuitGate::new(gate_type, wires, coeffs)
        })
        .collect();

    let kimchi_cs = kimchi::circuits::constraints::ConstraintSystem::<Fp>::create(gates)
        .build()
        .unwrap();

    let srs_json = std::fs::read_to_string("./test_data/srs.json").unwrap();
    let mut kimchi_srs: SRS<Vesta> = serde_json::from_str(srs_json.as_str()).unwrap();
    kimchi_srs.add_lagrange_basis(kimchi_cs.domain.d1);
    let kimchi_srs_arc = Arc::new(kimchi_srs);

    let &endo_q = <Vesta as KimchiCurve>::other_curve_endo();

    let group_map = <Vesta as CommitmentCurve>::Map::setup();
    let witness: [Vec<Fp>; 15] = array::from_fn(|_| vec![Fp::from(0); 4]);
    let prover_index: ProverIndex<_, OpeningProof<Vesta>> =
        ProverIndex::create(kimchi_cs, endo_q, kimchi_srs_arc);
    let proof =
        ProverProof::create::<BaseSponge, ScalarSponge>(&group_map, witness, &[], &prover_index)
            .expect("failed to generate proof");
    println!("proof: {:?}", proof);
}
