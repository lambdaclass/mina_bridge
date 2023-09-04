pub mod constraint_system;
pub mod srs;

use std::array;
use std::collections::HashMap;
use std::sync::Arc;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::circuits::gate::{CircuitGate, GateType};
use kimchi::circuits::wires::Wire;
use kimchi::curve::KimchiCurve;
use kimchi::groupmap::GroupMap;
use kimchi::keccak_sponge::{Keccak256FqSponge, Keccak256FrSponge};
use kimchi::o1_utils::FieldHelpers;
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::prover_index::ProverIndex;
use kimchi::{poly_commitment::commitment::CommitmentCurve, proof::ProverProof};

type BN254 = GroupAffine<ark_bn254::g1::Parameters>;
type Fp = ark_bn254::Fr;
type BaseSponge = Keccak256FqSponge<ark_bn254::Fq, ark_bn254::G1Affine, Fp>;
type ScalarSponge = Keccak256FrSponge<Fp>;

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
                .map(|coeff| Fp::from_hex(coeff).unwrap())
                .collect();
            CircuitGate::new(gate_type, wires, coeffs)
        })
        .collect();

    let kimchi_cs = kimchi::circuits::constraints::ConstraintSystem::<Fp>::create(gates)
        .build()
        .unwrap();

    let srs_json = std::fs::read_to_string("./test_data/srs.json").unwrap();
    let srs = srs::SRS::from(srs_json.as_str());
    let kimchi_srs = kimchi::poly_commitment::srs::SRS {
        g: srs.g.iter().map(BN254::from).collect::<Vec<_>>(),
        h: srs.h,
        lagrange_bases: HashMap::new(),
    };
    let kimchi_srs_arc = Arc::new(kimchi_srs);

    let &endo_q = <BN254 as KimchiCurve>::other_curve_endo();

    let group_map = <BN254 as CommitmentCurve>::Map::setup();
    let witness: [Vec<Fp>; 15] = array::from_fn(|_| vec![Fp::from(0); 4]);
    let prover_index: ProverIndex<_, OpeningProof<BN254>> =
        ProverIndex::create(kimchi_cs, endo_q, kimchi_srs_arc);
    let proof =
        ProverProof::create::<BaseSponge, ScalarSponge>(&group_map, witness, &[], &prover_index)
            .expect("failed to generate proof");
}
