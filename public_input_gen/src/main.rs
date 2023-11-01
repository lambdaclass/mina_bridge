use std::fs;

use ark_ec::short_weierstrass_jacobian::GroupAffine;
use ark_ec::{AffineCurve, ProjectiveCurve};
use ark_ff::{BigInteger256, PrimeField};
use kimchi::mina_curves::pasta::{Fp, Fq, Pallas, PallasParameters};
use kimchi::o1_utils::{math, FieldHelpers};
use kimchi::poly_commitment::srs::SRS;
use kimchi::precomputed_srs;
use num_traits::identities::Zero;
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

    let srs: SRS<Pallas> = precomputed_srs::get_srs();
    write_srs_into_file(&srs);

    // create and verify proof based on the witness
    prove_and_verify(&srs, state_proof.proof.openings.proof);
}

fn write_srs_into_file(srs: &SRS<Pallas>) {
    println!("Writing SRS into file...");
    let mut g = srs
        .g
        .iter()
        .map(|g_i| format!("[\"{}\",\"{}\"],", g_i.x.to_biguint(), g_i.y.to_biguint()))
        .collect::<Vec<_>>()
        .concat();
    // Removes last comma
    g.pop();
    let h = format!(
        "[\"{}\",\"{}\"]",
        srs.h.x.to_biguint(),
        srs.h.y.to_biguint()
    );
    let srs_json = format!("{{\"g\":[{}],\"h\":{}}}", g, h);
    fs::write("../verifier_circuit/test/srs.json", srs_json).unwrap();
}

fn prove_and_verify(srs: &SRS<Pallas>, opening: OpeningProof) {
    // verify the proof (propagate any errors)
    println!("Verifying dummy proof...");

    let sg_point = Pallas::new(
        Fp::from_hex(&opening.sg.0[2..]).unwrap(),
        Fp::from_hex(&opening.sg.1[2..]).unwrap(),
        false,
    );
    let z1_felt = Fq::from_hex(&opening.z_1[2..]).unwrap();
    let value_to_compare = compute_msm_for_verification(srs, &sg_point, &z1_felt);

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

fn compute_msm_for_verification(
    srs: &SRS<Pallas>,
    sg: &Pallas,
    z1: &Fq,
) -> GroupAffine<PallasParameters> {
    let rand_base_i = Fq::one();
    let sg_rand_base_i = Fq::one();
    let neg_rand_base_i = -rand_base_i;

    let nonzero_length = srs.g.len();
    let max_rounds = math::ceil_log2(nonzero_length);
    let padded_length = 1 << max_rounds;
    let padding = padded_length - nonzero_length;
    let mut points = vec![srs.h];
    points.extend(srs.g.clone());
    points.extend(vec![Pallas::zero(); padding]);
    let mut scalars = vec![Fq::zero(); padded_length + 1];

    points.push(*sg);
    scalars.push(neg_rand_base_i * z1 - sg_rand_base_i);

    let s = vec![Fq::one(); srs.g.len()];
    let terms: Vec<_> = s.iter().map(|s_i| sg_rand_base_i * s_i).collect();
    scalars
        .iter_mut()
        .skip(1)
        .zip(terms)
        .for_each(|(scalar, term)| {
            *scalar += term;
        });
    println!("Number of scalars: {}", scalars.len());

    // verify the equation
    let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
    // VariableBaseMSM::multi_scalar_mul(&points, &scalars)
    naive_msm(&points, &scalars)
}

fn naive_msm(points: &[Pallas], scalars: &[BigInteger256]) -> Pallas {
    let mut steps = vec![];
    let mut result = Pallas::zero();

    for i in 0..points.len() {
        result += &points[i].mul(scalars[i]).into_affine();
        steps.push(result);
    }
    fs::write(
        "../verifier_circuit/src/steps.json",
        serde_json::to_string(
            &steps
                .iter()
                .map(|step| {
                    [
                        step.x.to_biguint().to_string(),
                        step.y.to_biguint().to_string(),
                    ]
                })
                .collect::<Vec<_>>(),
        )
        .unwrap(),
    )
    .unwrap();

    result
}
