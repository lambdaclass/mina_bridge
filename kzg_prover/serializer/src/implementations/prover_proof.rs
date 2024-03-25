use kimchi::proof::PointEvaluations;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254PairingProof, BN254ProofEvaluations, ScalarField},
};

impl EVMSerializable for EVMSerializableType<BN254PairingProof> {
    fn to_bytes(self) -> Vec<u8> {
        let BN254PairingProof { quotient, blinding } = self.0;
        let quotient = EVMSerializableType(quotient);
        let blinding = EVMSerializableType(blinding);
        [quotient.to_bytes(), blinding.to_bytes()].concat()
    }
}

impl EVMSerializable for EVMSerializableType<BN254ProofEvaluations> {
    fn to_bytes(self) -> Vec<u8> {
        let evals = self.0;

        // First construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let mut optional_field_flags_encoded = vec![0; 32];
        let optional_field_flags = [
            &evals.public,
            &evals.range_check0_selector,
            &evals.range_check1_selector,
            &evals.foreign_field_add_selector,
            &evals.foreign_field_mul_selector,
            &evals.xor_selector,
            &evals.rot_selector,
            &evals.lookup_aggregation,
            &evals.lookup_table,
            &evals.lookup_sorted[0].clone(),
            &evals.lookup_sorted[1].clone(),
            &evals.lookup_sorted[2].clone(),
            &evals.lookup_sorted[3].clone(),
            &evals.lookup_sorted[4].clone(),
            &evals.runtime_lookup_table,
            &evals.runtime_lookup_table_selector,
            &evals.xor_lookup_selector,
            &evals.lookup_gate_lookup_selector,
            &evals.range_check_lookup_selector,
            &evals.foreign_field_mul_lookup_selector,
        ]
        .map(|field| if field.is_some() { 1 } else { 0 });
        for (i, mut flag) in optional_field_flags.into_iter().enumerate() {
            flag <<= 7 - (i % 8); // first flags are positioned on most significant bits
            optional_field_flags_encoded[i / 8] |= flag;
        }

        // Then we encode every eval.
        //
        // We should have one evaluation for each poly if `max_poly_size` is set
        // accordingly. Nonetheless some vectors have many evaluations, these are
        // `w` (15), `s` (6), `coefficients` (15) and `lookup_sorted` (5), but this is
        // because there're many polynomials defined for each one of those (e.g. there
        // is one coefficient poly for each column).
        //
        // An evaluation is composed of two scalars. So encoding the evaluations means
        // to concatenate each pair of scalars in a byte array.

        let encode_eval = |eval: PointEvaluations<Vec<ScalarField>>| {
            vec![
                EVMSerializableType(eval.zeta[0]).to_bytes(),
                EVMSerializableType(eval.zeta_omega[0]).to_bytes(),
            ]
            .into_iter()
            .flatten()
            .collect()
        };
        let encode_eval_option = |eval: Option<PointEvaluations<Vec<ScalarField>>>| {
            if let Some(eval) = eval {
                encode_eval(eval)
            } else {
                vec![]
            }
        };

        let encoded_evals: Vec<u8> = vec![
            encode_eval_option(evals.public),
            evals.w.into_iter().flat_map(encode_eval).collect(),
            encode_eval(evals.z),
            evals.s.into_iter().flat_map(encode_eval).collect(),
            evals
                .coefficients
                .into_iter()
                .flat_map(encode_eval)
                .collect(),
            encode_eval(evals.generic_selector),
            encode_eval(evals.poseidon_selector),
            encode_eval(evals.complete_add_selector),
            encode_eval(evals.mul_selector),
            encode_eval(evals.emul_selector),
            encode_eval(evals.endomul_scalar_selector),
            encode_eval_option(evals.range_check0_selector),
            encode_eval_option(evals.range_check1_selector),
            encode_eval_option(evals.foreign_field_add_selector),
            encode_eval_option(evals.foreign_field_mul_selector),
            encode_eval_option(evals.xor_selector),
            encode_eval_option(evals.rot_selector),
            encode_eval_option(evals.lookup_aggregation),
            encode_eval_option(evals.lookup_table),
            evals.lookup_sorted.into_iter().flat_map(encode_eval_option).collect(),
            encode_eval_option(evals.runtime_lookup_table),
            encode_eval_option(evals.runtime_lookup_table_selector),
            encode_eval_option(evals.xor_lookup_selector),
            encode_eval_option(evals.lookup_gate_lookup_selector),
            encode_eval_option(evals.range_check_lookup_selector),
            encode_eval_option(evals.foreign_field_mul_lookup_selector),
        ]
        .concat();

        [
            optional_field_flags_encoded.into_iter().rev().collect(),
            encoded_evals,
        ]
        .concat()
    }
}

#[cfg(test)]
mod test {
    use crate::type_aliases::{BaseField, G1Point, ScalarField};

    use super::*;

    #[test]
    fn test_pairing_proof_ser() {
        let pairing_proof = BN254PairingProof {
            quotient: G1Point::new(BaseField::from(1), BaseField::from(2), false),
            blinding: ScalarField::from(1),
        };
        let serialized = EVMSerializableType(pairing_proof).to_bytes();
        assert_eq!(
            serialized,
            vec![
                vec![0; 31],
                vec![1],
                vec![0; 31],
                vec![2],
                vec![0; 31],
                vec![1]
            ]
            .concat()
        );
    }
}
