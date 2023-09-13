use std::{array, fs};

use ark_ec::msm::VariableBaseMSM;
use ark_ec::short_weierstrass_jacobian::GroupProjective;
use ark_ec::ProjectiveCurve;
use ark_ff::PrimeField;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::{Fq, Pallas, PallasParameters};
use kimchi::o1_utils::{math, FieldHelpers};
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::poly_commitment::srs::SRS;
use kimchi::precomputed_srs;
use kimchi::{
    circuits::{
        gate::CircuitGate,
        polynomials::generic::testing::{create_circuit, fill_in_witness},
        wires::COLUMNS,
    },
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    poly_commitment::commitment::CommitmentCurve,
    proof::ProverProof,
    prover_index::testing::new_index_for_test_with_lookups,
};
use num_traits::identities::Zero;
use num_traits::One;

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<PallasParameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fq, SpongeParams>;

fn main() {
    let gates = create_circuit(0, 0);

    // create witness
    let mut witness: [Vec<Fq>; COLUMNS] = array::from_fn(|_| vec![Fq::zero(); gates.len()]);
    fill_in_witness(0, &mut witness, &[]);

    let srs: SRS<Pallas> = precomputed_srs::get_srs();
    // write_srs_into_file(&srs);

    // create and verify proof based on the witness
    prove_and_verify(&srs, gates, witness);
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
    fs::write("srs.json", srs_json).unwrap();
    println!("Done!");
}

fn prove_and_verify(srs: &SRS<Pallas>, gates: Vec<CircuitGate<Fq>>, witness: [Vec<Fq>; COLUMNS]) {
    println!("Proving...");
    let prover =
        new_index_for_test_with_lookups::<Pallas>(gates, 0, 0, vec![], Some(vec![]), false);
    let public_inputs = vec![];

    prover.verify(&witness, &public_inputs).unwrap();

    // add the proof to the batch
    let group_map = <Pallas as CommitmentCurve>::Map::setup();

    let proof = ProverProof::create_recursive::<BaseSponge, ScalarSponge>(
        &group_map,
        witness,
        &[],
        &prover,
        vec![],
        None,
    )
    .map_err(|e| e.to_string())
    .unwrap();
    println!("Done!");

    // verify the proof (propagate any errors)
    println!("Verifying...");
    let opening = proof.proof;
    let value_to_compare = compute_msm_for_verification(&srs, &opening).into_affine();
    println!("Done!");
    println!("--- Copy to o1js project ---");
    println!("const z1 = {}n;", opening.z1.to_biguint());
    println!(
        "const sg = new Group({{ x: {}n, y: {}n }});",
        opening.sg.x.to_biguint(),
        opening.sg.y.to_biguint()
    );
    println!(
        "const expected = new Group({{ x: {}n, y: {}n }});",
        value_to_compare.x.to_biguint(),
        value_to_compare.y.to_biguint()
    );
    println!("----------------------------");
}

fn compute_msm_for_verification(
    srs: &SRS<Pallas>,
    proof: &OpeningProof<Pallas>,
) -> GroupProjective<PallasParameters> {
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

    points.push(proof.sg);
    scalars.push(neg_rand_base_i * proof.z1 - sg_rand_base_i);

    let s = vec![Fq::one(); srs.g.len()];
    let terms: Vec<_> = s.iter().map(|s_i| sg_rand_base_i * s_i).collect();
    scalars
        .iter_mut()
        .zip(terms)
        .for_each(|(scalar, term)| *scalar += term);

    // verify the equation
    let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
    VariableBaseMSM::multi_scalar_mul(&points, &scalars)
}
