use std::fs;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use ark_ec::{AffineCurve, ProjectiveCurve};
use kimchi::mina_curves::pasta::{Fp, Fq, Pallas, PallasParameters};
use kimchi::o1_utils::FieldHelpers;
use num_traits::One;
use serde::Serialize;
use state_proof::{OpeningProof, StateProof};

mod state_proof;

#[derive(Serialize)]
struct Inputs {
    sg: [String; 2],
    z1: String,
    expected: [String; 2],
}

fn main() {
    let state_proof: StateProof = match fs::read_to_string("proof.json") {
        Ok(state_proof_file) => serde_json::from_str(&state_proof_file).unwrap(),
        Err(_) => StateProof::default(),
    };

    // create and verify proof based on the witness
    prove_and_verify(state_proof.proof.openings.proof);
}

fn prove_and_verify(opening: OpeningProof) {
    // verify the proof (propagate any errors)
    println!("Verifying dummy proof...");

    let sg_point = Pallas::new(
        Fp::from_hex(&opening.sg.0[2..]).unwrap(),
        Fp::from_hex(&opening.sg.1[2..]).unwrap(),
        false,
    );
    let z1_felt = Fq::from_hex(&opening.z_1[2..]).unwrap();
    let value_to_compare = compute_verification(&sg_point, &z1_felt);

    fs::write(
        "../verifier_circuit/src/inputs.json",
        serde_json::to_string(&Inputs {
            sg: [
                sg_point.x.to_biguint().to_string(),
                sg_point.y.to_biguint().to_string(),
            ],
            z1: z1_felt.to_biguint().to_string(),
            expected: [
                value_to_compare.x.to_biguint().to_string(),
                value_to_compare.y.to_biguint().to_string(),
            ],
        })
        .unwrap(),
    )
    .unwrap();
}

fn compute_verification(sg: &Pallas, z1: &Fq) -> GroupAffine<PallasParameters> {
    let rand_base_i = Fq::one();
    let sg_rand_base_i = Fq::one();
    let neg_rand_base_i = -rand_base_i;

    sg.mul(neg_rand_base_i * z1 - sg_rand_base_i).into_affine()
}
