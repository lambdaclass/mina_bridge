use std::{array, fs};

use ark_ff::fields::FpParameters;
use kimchi::groupmap::GroupMap;
use kimchi::mina_curves::pasta::fields::{FpParameters as FrParameters, FqParameters};
use kimchi::mina_curves::pasta::{Fq, Pallas, PallasParameters};
use kimchi::o1_utils::FieldHelpers;
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
    verifier::verify,
};
use num_traits::identities::Zero;

type SpongeParams = PlonkSpongeConstantsKimchi;
type BaseSponge = DefaultFqSponge<PallasParameters, SpongeParams>;
type ScalarSponge = DefaultFrSponge<Fq, SpongeParams>;

fn main() {
    let gates = create_circuit(0, 0);

    // create witness
    let mut witness: [Vec<Fq>; COLUMNS] = array::from_fn(|_| vec![Fq::zero(); gates.len()]);
    fill_in_witness(0, &mut witness, &[]);
    println!("VESTA ORDER: {}", <FqParameters as FpParameters>::MODULUS);
    println!("PALLAS ORDER: {}", FrParameters::MODULUS);

    write_srs_into_file();

    // create and verify proof based on the witness
    prove_and_verify(gates, witness);
}

fn write_srs_into_file() {
    println!("Writing SRS into file...");
    let srs: SRS<Pallas> = precomputed_srs::get_srs();
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

fn prove_and_verify(gates: Vec<CircuitGate<Fq>>, witness: [Vec<Fq>; COLUMNS]) {
    println!("Proving...");
    let index = new_index_for_test_with_lookups::<Pallas>(gates, 0, 0, vec![], Some(vec![]), false);

    let verifier_index = index.verifier_index();
    let prover = index;
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
    verify::<Pallas, BaseSponge, ScalarSponge>(&group_map, &verifier_index, &proof, &public_inputs)
        .unwrap();
    println!("Done!");
}

/// Reference tests for comparing behaviour with the circuit implementation in o1js.
mod partial_verification {
    use ark_ec::AffineCurve;
    use ark_ff::{One, PrimeField};
    use ark_poly::domain::EvaluationDomain;
    use kimchi::{
        curve::KimchiCurve, error::VerifyError, poly_commitment::PolyComm,
        verifier_index::VerifierIndex,
    };

    use super::*;

    fn to_batch_step2<'a, G>(
        verifier_index: &VerifierIndex<G>,
        public_input: &'a [<G as AffineCurve>::ScalarField],
    ) -> Result<(), VerifyError>
    where
        G: KimchiCurve,
        G::BaseField: PrimeField,
    {
        println!("to_batch(), step 2: Commit to the negated public input polynomial.");
        let public_comm = {
            if public_input.len() != verifier_index.public {
                return Err(VerifyError::IncorrectPubicInputLength(
                    verifier_index.public,
                ));
            }
            let lgr_comm = verifier_index
                .srs()
                .lagrange_bases
                .get(&verifier_index.domain.size())
                .expect("pre-computed committed lagrange bases not found");
            let com: Vec<_> = lgr_comm.iter().take(verifier_index.public).collect();
            let elm: Vec<_> = public_input.iter().map(|s| -*s).collect();
            let public_comm = PolyComm::<G>::multi_scalar_mul(&com, &elm);
            verifier_index
                .srs()
                .mask_custom(
                    public_comm,
                    &PolyComm {
                        unshifted: vec![G::ScalarField::one(); 1],
                        shifted: None,
                    },
                )
                .unwrap()
                .commitment
        };
        println!("Done, public_comm: {:?}", public_comm);
        Ok(())
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn to_batch() {
            let gates = create_circuit(0, 0);
            let index =
                new_index_for_test_with_lookups::<Pallas>(gates, 0, 0, vec![], Some(vec![]), false);
            let verifier_index = index.verifier_index();
            let public_inputs = vec![];

            to_batch_step2(&verifier_index, &public_inputs).unwrap();
        }
    }
}
