use ark_poly::EvaluationDomain;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::BN254VerifierIndex,
};

impl EVMSerializable for EVMSerializableType<BN254VerifierIndex> {
    fn to_bytes(self) -> Vec<u8> {
        let index = self.0;

        // First construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let mut optional_field_flags_encoded = vec![0; 32];
        let optional_field_flags = [
            &index.range_check0_comm,
            &index.range_check1_comm,
            &index.foreign_field_add_comm,
            &index.foreign_field_mul_comm,
            &index.xor_comm,
            &index.rot_comm,
        ]
        .into_iter()
        .map(|field| if field.is_some() { 1 } else { 0 })
        .chain([if index.lookup_index.is_some() { 1 } else { 0 }]);
        for (i, mut flag) in optional_field_flags.into_iter().enumerate() {
            flag <<= i % 8; // first flags are positioned on least significant bits
            optional_field_flags_encoded[i / 8] |= flag;
        }

        // Encode domain
        let mut encoded_domain = vec![];
        encoded_domain.extend(EVMSerializableType(index.domain.size()).to_bytes());
        encoded_domain.extend(EVMSerializableType(index.domain.group_gen).to_bytes());

        // Encode integers
        let encoded_max_poly_size = EVMSerializableType(index.max_poly_size).to_bytes();
        let encoded_zk_rows = EVMSerializableType(index.zk_rows).to_bytes();
        let encoded_public_len = EVMSerializableType(index.public).to_bytes();

        // Encode commitments
        let encoded_sigma_comm = index
            .sigma_comm
            .into_iter()
            .flat_map(|comm| EVMSerializableType(comm).to_bytes())
            .collect::<Vec<_>>();
        let encoded_coefficients_comm = index
            .coefficients_comm
            .into_iter()
            .flat_map(|comm| EVMSerializableType(comm).to_bytes())
            .collect::<Vec<_>>();
        let encoded_generic_comm = EVMSerializableType(index.generic_comm).to_bytes();
        let encoded_psm_comm = EVMSerializableType(index.psm_comm).to_bytes();
        let encoded_complete_add_comm = EVMSerializableType(index.complete_add_comm).to_bytes();
        let encoded_mul_comm = EVMSerializableType(index.mul_comm).to_bytes();
        let encoded_emul_comm = EVMSerializableType(index.emul_comm).to_bytes();
        let encoded_endomul_scalar_comm = EVMSerializableType(index.endomul_scalar_comm).to_bytes();

        // Encode optional commitments (will encode to empty vector if None)
        let encoded_range_check0_comm = EVMSerializableType(index.range_check0_comm).to_bytes();
        let encoded_range_check1_comm = EVMSerializableType(index.range_check1_comm).to_bytes();
        let encoded_foreign_field_add_comm = EVMSerializableType(index.foreign_field_add_comm).to_bytes();
        let encoded_foreign_field_mul_comm = EVMSerializableType(index.foreign_field_mul_comm).to_bytes();
        let encoded_xor_comm = EVMSerializableType(index.xor_comm).to_bytes();
        let encoded_rot_comm = EVMSerializableType(index.rot_comm).to_bytes();

        let encoded_coefficients_comm = index
            .shift
            .into_iter()
            .flat_map(|comm| EVMSerializableType(comm).to_bytes())
            .collect();

        [
            optional_field_flags_encoded,
            encoded_domain,
            encoded_max_poly_size,
            encoded_zk_rows,
            encoded_public_len,
            encoded_sigma_comm,
            encoded_coefficients_comm,
            encoded_generic_comm,
            encoded_psm_comm,
            encoded_complete_add_comm,
            encoded_mul_comm,
            encoded_emul_comm,
            encoded_endomul_scalar_comm,
            encoded_range_check0_comm,
            encoded_range_check1_comm,
            encoded_foreign_field_add_comm,
            encoded_foreign_field_mul_comm,
            encoded_xor_comm,
            encoded_rot_comm
        ]
        .concat()
    }
}
