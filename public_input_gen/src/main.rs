use std::fs;

use ark_ec::msm::VariableBaseMSM;
use ark_ec::short_weierstrass_jacobian::GroupProjective;
use ark_ec::ProjectiveCurve;
use kimchi::mina_curves::pasta::{Fp, Fq, Pallas, PallasParameters};
use kimchi::o1_utils::FieldHelpers;
use kimchi::poly_commitment::srs::SRS;
use kimchi::precomputed_srs;
use num_traits::{One, Zero};
use serde::Serialize;
use state_proof::{OpeningProof, StateProof};

mod state_proof;

#[derive(Serialize)]
struct Point {
    x: String,
    y: String,
}

#[derive(Serialize)]
struct Inputs {
    lr: Vec<[Point; 2]>,
    z1: String,
    z2: String,
    delta: Point,
    sg: Point,
    expected: Point,
}

fn main() {
    let state_proof: StateProof = match fs::read_to_string("./src/proof.json") {
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

    let lr_map = opening.lr.iter().map(|(l_i, r_i)| {
        [
            Pallas::new(
                Fp::from_hex(&l_i.0[2..]).unwrap(),
                Fp::from_hex(&l_i.1[2..]).unwrap(),
                false,
            ),
            Pallas::new(
                Fp::from_hex(&r_i.0[2..]).unwrap(),
                Fp::from_hex(&r_i.1[2..]).unwrap(),
                false,
            ),
        ]
    });
    let z1 = Fq::from_hex(&opening.z_1[2..]).unwrap();
    let z2 = Fq::from_hex(&opening.z_2[2..]).unwrap();
    let delta = Pallas::new(
        Fp::from_hex(&opening.delta.0[2..]).unwrap(),
        Fp::from_hex(&opening.delta.1[2..]).unwrap(),
        false,
    );
    let sg = Pallas::new(
        Fp::from_hex(&opening.sg.0[2..]).unwrap(),
        Fp::from_hex(&opening.sg.1[2..]).unwrap(),
        false,
    );
    let value_to_compare = compute_msm_verification(srs, &sg, &z1).into_affine();

    fs::write(
        "../verifier_circuit/src/inputs.json",
        serde_json::to_string(&Inputs {
            lr: lr_map
                .map(|[l_i, r_i]| {
                    [
                        Point {
                            x: l_i.x.to_biguint().to_string(),
                            y: l_i.y.to_biguint().to_string(),
                        },
                        Point {
                            x: r_i.x.to_biguint().to_string(),
                            y: r_i.y.to_biguint().to_string(),
                        },
                    ]
                })
                .collect(),
            z1: z1.to_biguint().to_string(),
            z2: z2.to_biguint().to_string(),
            delta: Point {
                x: delta.x.to_biguint().to_string(),
                y: delta.y.to_biguint().to_string(),
            },
            sg: Point {
                x: sg.x.to_biguint().to_string(),
                y: sg.y.to_biguint().to_string(),
            },
            expected: Point {
                x: value_to_compare.x.to_biguint().to_string(),
                y: value_to_compare.y.to_biguint().to_string(),
            },
        })
        .unwrap(),
    )
    .unwrap();
}

fn compute_msm_verification(
    srs: &SRS<Pallas>,
    sg: &Pallas,
    z1: &Fq,
) -> GroupProjective<PallasParameters> {
    let mut points = vec![srs.h];
    let mut scalars = vec![Fq::zero()];

    let rand_base_i = Fq::one();
    let sg_rand_base_i = Fq::one();
    let neg_rand_base_i = -rand_base_i;

    points.push(*sg);
    scalars.push(neg_rand_base_i * z1 - sg_rand_base_i);

    let scalars: Vec<_> = scalars.iter().map(|scalar| scalar.0).collect();

    VariableBaseMSM::multi_scalar_mul(&points, &scalars)
}
