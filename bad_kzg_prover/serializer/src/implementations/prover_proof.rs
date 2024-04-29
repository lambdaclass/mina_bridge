use kimchi::proof::PointEvaluations;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{
        BN254PairingProof, BN254ProofEvaluations, BN254ProverCommitments, BN254ProverProof,
        ScalarField,
    },
};

impl EVMSerializable for EVMSerializableType<BN254PairingProof> {
    fn to_bytes(self) -> Vec<u8> {
        let BN254PairingProof { quotient, blinding } = self.0;
        let quotient = EVMSerializableType(quotient);
        let blinding = EVMSerializableType(blinding);
        [quotient.to_bytes(), blinding.to_bytes()].concat()
    }
}

impl EVMSerializable for EVMSerializableType<BN254ProverCommitments> {
    fn to_bytes(self) -> Vec<u8> {
        let comms = self.0;

        // There's only one optional field (LookupCommitments) but it has an
        // optional field in it and two non-optional, so we'll flat out
        // LookupCommitments and define only two flags.
        let mut optional_field_flags_encoded = vec![0; 32]; // allocate a word for them
                                                            // The first flag will indicate if LookupCommitments is Some:
        if let Some(lookup_comms) = &comms.lookup {
            optional_field_flags_encoded[31] |= 0b01;
            // the other flag if lookup_comms.runtime is Some:
            if lookup_comms.runtime.is_some() {
                optional_field_flags_encoded[31] |= 0b10;
            }
        }

        // Then we encode every commitment. We'll flat out LookupCommitments:

        let mut encoded_comms = vec![
            comms
                .w_comm
                .into_iter()
                .flat_map(|p| EVMSerializableType(p).to_bytes())
                .collect(),
            EVMSerializableType(comms.z_comm).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[0]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[1]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[2]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[3]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[4]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[5]).to_bytes(),
            EVMSerializableType(comms.t_comm.unshifted[6]).to_bytes(),
        ]
        .concat();
        if let Some(lookup_comms) = comms.lookup {
            // `sorted` contains an unspecified amount of commitments, so
            // first we'll encode the length as a 256 bit integer:
            let sorted_len_bytes = lookup_comms.sorted.len().to_be_bytes();
            // pad with zeros and push bytes:
            encoded_comms.extend(vec![0; 32 - sorted_len_bytes.len()]);
            encoded_comms.extend(sorted_len_bytes);

            encoded_comms.extend(
                lookup_comms
                    .sorted
                    .into_iter()
                    .flat_map(|p| EVMSerializableType(p).to_bytes())
                    .collect::<Vec<_>>(),
            );
            encoded_comms.extend(EVMSerializableType(lookup_comms.aggreg).to_bytes());
            if let Some(runtime) = lookup_comms.runtime {
                encoded_comms.extend(EVMSerializableType(runtime).to_bytes());
            }
        }

        [optional_field_flags_encoded, encoded_comms].concat()
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
            flag <<= i % 8; // first flags are positioned on least significant bits
            optional_field_flags_encoded[i / 8] |= flag;
        }

        // Then we encode every eval.
        //
        // We should have one evaluation for each poly if `max_poly_size` is set
        // accordingly and no polynomial gets chunked.
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
            encode_eval_option(evals.public),
            encode_eval_option(evals.range_check0_selector),
            encode_eval_option(evals.range_check1_selector),
            encode_eval_option(evals.foreign_field_add_selector),
            encode_eval_option(evals.foreign_field_mul_selector),
            encode_eval_option(evals.xor_selector),
            encode_eval_option(evals.rot_selector),
            encode_eval_option(evals.lookup_aggregation),
            encode_eval_option(evals.lookup_table),
            evals
                .lookup_sorted
                .into_iter()
                .flat_map(encode_eval_option)
                .collect(),
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

impl EVMSerializable for EVMSerializableType<BN254ProverProof> {
    fn to_bytes(self) -> Vec<u8> {
        let BN254ProverProof {
            commitments,
            proof,
            evals,
            ft_eval1,
            ..
        } = self.0;

        [
            EVMSerializableType(commitments).to_bytes(),
            EVMSerializableType(proof).to_bytes(),
            EVMSerializableType(evals).to_bytes(),
            EVMSerializableType(ft_eval1).to_bytes(),
        ].concat()
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
