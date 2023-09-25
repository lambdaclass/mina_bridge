pub mod constraint_system;

use std::array;
use std::str::FromStr;
use std::sync::Arc;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
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
use kimchi::verifier::verify;
use kimchi::{poly_commitment::commitment::CommitmentCurve, proof::ProverProof};

type Parameters = VestaParameters;
type Curve = GroupAffine<Parameters>;
type SpongeConstants = PlonkSpongeConstantsKimchi;
type Field = Fp;

type BaseSponge = DefaultFqSponge<Parameters, SpongeConstants>;
type ScalarSponge = DefaultFrSponge<Field, SpongeConstants>;

fn main() {
    let gates = create_gates();

    let constraint_system = kimchi::circuits::constraints::ConstraintSystem::<Field>::create(gates)
        .public(3)
        .build()
        .unwrap();

    let srs = create_srs(&constraint_system);

    let &endo_q = <Curve as KimchiCurve>::other_curve_endo();
    let group_map = <Curve as CommitmentCurve>::Map::setup();
    let witness = create_witness();
    let prover_index: ProverIndex<_, OpeningProof<Curve>> =
        ProverIndex::create(constraint_system, endo_q, srs);

    let proof =
        ProverProof::create::<BaseSponge, ScalarSponge>(&group_map, witness, &[], &prover_index)
            .expect("failed to generate proof");

    let verifier_index = prover_index.verifier_index();
    verify::<Curve, BaseSponge, ScalarSponge, OpeningProof<Curve>>(
        &group_map,
        &verifier_index,
        &proof,
        &[Field::from(2), Field::from(3), Field::from(5)],
    )
    .expect("Proof is not valid");

    println!("Done!");
}

fn create_gates() -> Vec<CircuitGate<Field>> {
    let cs_json = std::fs::read_to_string("./test_data/constraint_system.json").unwrap();
    let cs = constraint_system::ConstraintSystem::from(cs_json.as_str());
    let elem_list = cs.0;

    elem_list
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
            let coeffs: Vec<Field> = gate
                .coeffs
                .iter()
                .map(|coeff| Field::from_str(coeff).unwrap())
                .collect();
            CircuitGate::new(gate_type, wires, coeffs)
        })
        .collect()
}

fn create_witness() -> [Vec<Field>; 15] {
    let witness_json = std::fs::read_to_string("./test_data/witness.json").unwrap();
    let witness_str: Vec<Vec<String>> = serde_json::from_str(&witness_json).unwrap();
    let mut witness: [Vec<Field>; 15] = array::from_fn(|_| vec![]);

    // Convert matrix of strings to matrix of Fields
    for (col_str, mut col) in witness.iter_mut().zip(witness_str) {
        for (field_str, field) in col.iter_mut().zip(col_str) {
            *field = Field::from_str(&field_str).unwrap();
        }
    }

    witness
}

fn create_srs(
    kimchi_cs: &kimchi::circuits::constraints::ConstraintSystem<Field>,
) -> Arc<SRS<GroupAffine<VestaParameters>>> {
    let srs_json = std::fs::read_to_string("./test_data/srs_pasta.json").unwrap();
    let mut kimchi_srs: SRS<Curve> = serde_json::from_str(srs_json.as_str()).unwrap();
    kimchi_srs.add_lagrange_basis(kimchi_cs.domain.d1);

    Arc::new(kimchi_srs)
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
