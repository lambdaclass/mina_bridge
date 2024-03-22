use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254PairingProof, BN254ProofEvaluations},
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

        // first construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let mut optional_field_flags_encoded = vec![0; 32];
        let optional_field_flags = [
            evals.public,
            evals.range_check0_selector,
            evals.range_check1_selector,
            evals.foreign_field_add_selector,
            evals.foreign_field_mul_selector,
            evals.xor_selector,
            evals.rot_selector,
            evals.lookup_aggregation,
            evals.lookup_table,
            evals.lookup_sorted[0].clone(),
            evals.lookup_sorted[1].clone(),
            evals.lookup_sorted[2].clone(),
            evals.lookup_sorted[3].clone(),
            evals.lookup_sorted[4].clone(),
            evals.runtime_lookup_table,
            evals.runtime_lookup_table_selector,
            evals.xor_lookup_selector,
            evals.lookup_gate_lookup_selector,
            evals.range_check_lookup_selector,
            evals.foreign_field_mul_lookup_selector,
        ]
        .map(|field| if field.is_some() { 1 } else { 0 });
        for (i, mut flag) in optional_field_flags.into_iter().enumerate() {
            flag <<= 7 - (i % 8); // first flags are positioned on most significant bits
            optional_field_flags_encoded[i / 8] |= flag;
        }

        // then we encode every eval;

        [optional_field_flags_encoded.into_iter().rev().collect(), vec![]].concat()
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
