use std::fs;

use kimchi::{
    circuits::wires::{COLUMNS, PERMUTS},
    proof::{LookupCommitments, PointEvaluations},
};
use serializer::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{
        BN254PairingProof, BN254PolyComm, BN254ProofEvaluations, BN254ProverCommitments, BaseField,
        G1Point, ScalarField,
    },
};

fn main() {
    generate_solidity_test_data();
}

fn generate_solidity_test_data() {
    // pairing proof
    let pairing_proof = BN254PairingProof {
        quotient: G1Point::new(BaseField::from(1), BaseField::from(2), false),
        blinding: ScalarField::from(1),
    };

    // proof evals
    let gen_test_eval = || PointEvaluations {
        zeta: vec![ScalarField::from(1)],
        zeta_omega: vec![ScalarField::from(42)],
    };
    let proof_evals = BN254ProofEvaluations {
        public: Some(gen_test_eval()),
        w: [0; COLUMNS].map(|_| gen_test_eval()),
        z: gen_test_eval(),
        s: [0; PERMUTS - 1].map(|_| gen_test_eval()),
        coefficients: [0; 15].map(|_| gen_test_eval()),
        generic_selector: gen_test_eval(),
        poseidon_selector: gen_test_eval(),
        complete_add_selector: gen_test_eval(),
        mul_selector: gen_test_eval(),
        emul_selector: gen_test_eval(),
        endomul_scalar_selector: gen_test_eval(),

        range_check0_selector: Some(gen_test_eval()),
        range_check1_selector: None,
        foreign_field_add_selector: Some(gen_test_eval()),
        foreign_field_mul_selector: None,
        xor_selector: None,
        rot_selector: None,
        lookup_aggregation: None,
        lookup_table: None,
        lookup_sorted: [0; 5].map(|_| None),
        runtime_lookup_table: None,
        runtime_lookup_table_selector: None,
        xor_lookup_selector: None,
        lookup_gate_lookup_selector: None,
        range_check_lookup_selector: None,
        foreign_field_mul_lookup_selector: None,
    };

    // proof commitments
    let gen_test_comm = || BN254PolyComm {
        unshifted: vec![G1Point::new(BaseField::from(1), BaseField::from(2), false)],
        shifted: None,
    };
    let proof_comms = BN254ProverCommitments {
        w_comm: [0; COLUMNS].map(|_| gen_test_comm()),
        z_comm: gen_test_comm(),
        t_comm: gen_test_comm(),
        lookup: Some(LookupCommitments {
            sorted: vec![gen_test_comm(); 5],
            aggreg: gen_test_comm(),
            runtime: Some(gen_test_comm()),
        }),
    };

    fs::write(
        "../../eth_verifier/unit_test_data/pairing_proof.bin",
        EVMSerializableType(pairing_proof).to_bytes(),
    )
    .unwrap();
    fs::write(
        "../../eth_verifier/unit_test_data/proof_evals.bin",
        EVMSerializableType(proof_evals).to_bytes(),
    )
    .unwrap();
    fs::write(
        "../../eth_verifier/unit_test_data/proof_comms.bin",
        EVMSerializableType(proof_comms).to_bytes(),
    )
    .unwrap();
}
