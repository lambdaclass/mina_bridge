pub mod constraint_system;
pub mod inputs;

use std::str::FromStr;
use std::sync::Arc;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use constraint_system::Gate;
use kimchi::circuits::constraints::ConstraintSystem as KimchiConstraintSystem;
use kimchi::circuits::gate::{CircuitGate, GateType};
use kimchi::circuits::wires::Wire;
use kimchi::curve::KimchiCurve;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::{Fp, VestaParameters};
use kimchi::mina_poseidon::constants::PlonkSpongeConstantsKimchi;
use kimchi::mina_poseidon::sponge::{DefaultFqSponge, DefaultFrSponge};
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::poly_commitment::srs::SRS;
use kimchi::prover_index::ProverIndex;
use kimchi::snarky::constants::Constants;
use kimchi::snarky::constraint_system::SnarkyConstraintSystem;
use kimchi::verifier::verify;
use kimchi::{poly_commitment::commitment::CommitmentCurve, proof::ProverProof};

use crate::inputs::Inputs;

type Parameters = VestaParameters;
type Curve = GroupAffine<Parameters>;
type SpongeConstants = PlonkSpongeConstantsKimchi;
type Field = Fp;

type BaseSponge = DefaultFqSponge<Parameters, SpongeConstants>;
type ScalarSponge = DefaultFrSponge<Field, SpongeConstants>;

fn main() {
    let cs_json = std::fs::read_to_string("./test_data/constraint_system.json").unwrap();
    let cs = constraint_system::ConstraintSystem::from(cs_json.as_str());
    let elem_list = cs.0;
    let gates = convert_to_circuit_gates(elem_list);

    let group_map = <Curve as CommitmentCurve>::Map::setup();

    let inputs_json = std::fs::read_to_string("../evm_bridge/src/inputs.json").unwrap();
    let inputs = Inputs::from(inputs_json.as_str());
    let get_public_input = |i: usize| -> Field {
        match i {
            0 => Field::from_str(&inputs.sg[0]).unwrap(),
            1 => Field::from_str(&inputs.sg[1]).unwrap(),
            _ => Field::from(0),
        }
    };
    let witness = create_witness(get_public_input);
    println!("witness: {:?}", witness);

    let prover_index = create_prover_index(gates);
    let proof =
        ProverProof::create::<BaseSponge, ScalarSponge>(&group_map, witness, &[], &prover_index)
            .expect("failed to generate proof");
    println!("proof: {:?}", proof);

    let verifier_index = prover_index.verifier_index();
    verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
        &group_map,
        &verifier_index,
        &proof,
        &[get_public_input(0), get_public_input(1)],
    )
    .expect("Proof is not valid");

    println!("Done!");
}

fn create_witness<F: Fn(usize) -> Field>(get_public_input: F) -> [Vec<Field>; 15] {
    let constants = Constants::new::<Curve>();
    let mut snarky_cs = SnarkyConstraintSystem::create(constants);
    snarky_cs.set_public_input_size(2);

    let witness = snarky_cs.compute_witness(get_public_input);

    witness.try_into().unwrap()
}

fn create_prover_index(gates: Vec<CircuitGate<Field>>) -> ProverIndex<Curve, OpeningProof<Curve>> {
    let kimchi_cs = KimchiConstraintSystem::<Field>::create(gates)
        .public(2)
        .build()
        .unwrap();

    let srs_json = std::fs::read_to_string("./test_data/srs_pasta.json").unwrap();
    let mut kimchi_srs: SRS<Curve> = serde_json::from_str(srs_json.as_str()).unwrap();
    kimchi_srs.add_lagrange_basis(kimchi_cs.domain.d1);
    let kimchi_srs_arc = Arc::new(kimchi_srs);

    let &endo_q = <Curve as KimchiCurve>::other_curve_endo();

    ProverIndex::create(kimchi_cs, endo_q, kimchi_srs_arc)
}

fn convert_to_circuit_gates(elem_list: Vec<Gate>) -> Vec<CircuitGate<Field>> {
    elem_list
        .iter()
        .map(|gate| {
            let gate_type = if gate.r#type == "Generic" {
                GateType::Generic
            } else if gate.r#type == "VarBaseMul" {
                GateType::VarBaseMul
            } else if gate.r#type == "CompleteAdd" {
                GateType::CompleteAdd
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
            let coeffs: Vec<Field> = gate
                .coeffs
                .iter()
                .map(|coeff| Field::from_str(coeff).unwrap())
                .collect();
            CircuitGate::new(gate_type, wires, coeffs)
        })
        .collect()
}

/*

    let srs = SRS::<Curve>::create(kimchi_cs.domain.d1.size as usize);

    let out = rmp_serde::encode::to_vec(&srs).unwrap();
    let mut file = std::fs::File::create("srs.rmp").unwrap();
    file.write_all(&out).unwrap();

    let out_json = serde_json::to_vec(&srs).unwrap();
    let mut file = std::fs::File::create("srs.json").unwrap();
    file.write_all(&out_json).unwrap();

*/
