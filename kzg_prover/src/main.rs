pub mod constraint_system;

use std::array;
use std::str::FromStr;
use std::sync::Arc;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::circuits::gate::{CircuitGate, GateType};
use kimchi::circuits::wires::Wire;
use kimchi::curve::KimchiCurve;
use kimchi::groupmap::GroupMap;
use kimchi::mina_poseidon::constants::PlonkSpongeConstantsKimchi;
use kimchi::mina_poseidon::sponge::{DefaultFqSponge, DefaultFrSponge};
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::poly_commitment::srs::SRS;
use kimchi::prover_index::ProverIndex;
use kimchi::{poly_commitment::commitment::CommitmentCurve, proof::ProverProof};

type Parameters = ark_bn254::g1::Parameters;
type Curve = GroupAffine<Parameters>;
type SpongeConstants = PlonkSpongeConstantsKimchi;
type Field = ark_bn254::Fr;

type BaseSponge = DefaultFqSponge<Parameters, SpongeConstants>;
type ScalarSponge = DefaultFrSponge<Field, SpongeConstants>;

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
            let coeffs: Vec<Field> = gate
                .coeffs
                .iter()
                .map(|coeff| Field::from_str(coeff).unwrap())
                .collect();
            CircuitGate::new(gate_type, wires, coeffs)
        })
        .collect();

    let mut kimchi_cs = kimchi::circuits::constraints::ConstraintSystem::<Field>::create(gates)
        .build()
        .unwrap();
    kimchi_cs.feature_flags.foreign_field_add = true;
    kimchi_cs.feature_flags.foreign_field_mul = true;

    let srs_json = std::fs::read_to_string("./test_data/srs.json").unwrap();
    let mut kimchi_srs: SRS<Curve> = serde_json::from_str(srs_json.as_str()).unwrap();
    kimchi_srs.add_lagrange_basis(kimchi_cs.domain.d1);
    let kimchi_srs_arc = Arc::new(kimchi_srs);

    let &endo_q = <Curve as KimchiCurve>::other_curve_endo();

    let group_map = <Curve as CommitmentCurve>::Map::setup();
    let witness: [Vec<Field>; 15] = array::from_fn(|_| vec![Field::from(0); 4]);
    let prover_index: ProverIndex<_, OpeningProof<Curve>> =
        ProverIndex::create(kimchi_cs, endo_q, kimchi_srs_arc);
    let proof =
        ProverProof::create::<BaseSponge, ScalarSponge>(&group_map, witness, &[], &prover_index)
            .expect("failed to generate proof");
    println!("proof: {:?}", proof);
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
