use ark_poly::EvaluationDomain;
use kimchi::circuits::lookup::lookups::LookupInfo;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254LookupSelectors, BN254LookupVerifierIndex, BN254VerifierIndex},
    utils::encode_bools_to_uint256_flags_bytes,
};

impl EVMSerializable for EVMSerializableType<LookupInfo> {
    fn to_bytes(self) -> Vec<u8> {
        let info = self.0;

        let encoded_max_per_row = EVMSerializableType(info.max_per_row).to_bytes();
        let encoded_max_joint_size = EVMSerializableType(info.max_joint_size).to_bytes();

        [encoded_max_per_row, encoded_max_joint_size].concat()
    }
}

impl EVMSerializable for EVMSerializableType<BN254LookupSelectors> {
    fn to_bytes(self) -> Vec<u8> {
        let sels = self.0;

        // First construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let optional_field_bools =
            [&sels.xor, &sels.lookup, &sels.range_check, &sels.ffmul].map(Option::is_some);
        let encoded_optional_field_flags =
            encode_bools_to_uint256_flags_bytes(&optional_field_bools);

        let encoded_xor = EVMSerializableType(sels.xor).to_bytes();
        let encoded_lookup = EVMSerializableType(sels.lookup).to_bytes();
        let encoded_range_check = EVMSerializableType(sels.range_check).to_bytes();
        let encoded_ffmul = EVMSerializableType(sels.ffmul).to_bytes();

        [
            encoded_optional_field_flags,
            encoded_xor,
            encoded_lookup,
            encoded_range_check,
            encoded_ffmul,
        ]
        .concat()
    }
}

impl EVMSerializable for EVMSerializableType<BN254LookupVerifierIndex> {
    fn to_bytes(self) -> Vec<u8> {
        let index = self.0;

        // First construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let optional_field_bools =
            [&index.table_ids, &index.runtime_tables_selector].map(Option::is_some);
        let encoded_optional_field_flags =
            encode_bools_to_uint256_flags_bytes(&optional_field_bools);

        if index.lookup_table.len() != 1 {
            panic!("LookupVerifierIndex's lookup table isn't of size 1");
        }
        let encoded_lookup_table = EVMSerializableType(index.lookup_table[0].clone()).to_bytes();
        let encoded_lookup_selectors = EVMSerializableType(index.lookup_selectors).to_bytes();
        let encoded_table_ids = EVMSerializableType(index.table_ids).to_bytes();
        let encoded_lookup_info = EVMSerializableType(index.lookup_info).to_bytes();
        let encoded_runtime_tables_selector =
            EVMSerializableType(index.runtime_tables_selector).to_bytes();

        [
            encoded_optional_field_flags,
            encoded_lookup_table,
            encoded_lookup_selectors,
            encoded_table_ids,
            encoded_lookup_info,
            encoded_runtime_tables_selector,
        ]
        .concat()
    }
}

impl EVMSerializable for EVMSerializableType<BN254VerifierIndex> {
    fn to_bytes(self) -> Vec<u8> {
        let index = self.0;

        // First construct a bitmap, where every bit will be a flag that indicates if
        // a field is Some or None:
        let optional_field_bools = [
            &index.range_check0_comm,
            &index.range_check1_comm,
            &index.foreign_field_add_comm,
            &index.foreign_field_mul_comm,
            &index.xor_comm,
            &index.rot_comm,
        ]
        .into_iter()
        .map(Option::is_some)
        .chain([index.lookup_index.is_some()])
        .collect::<Vec<_>>();
        let encoded_optional_field_flags =
            encode_bools_to_uint256_flags_bytes(&optional_field_bools);

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
        let encoded_foreign_field_add_comm =
            EVMSerializableType(index.foreign_field_add_comm).to_bytes();
        let encoded_foreign_field_mul_comm =
            EVMSerializableType(index.foreign_field_mul_comm).to_bytes();
        let encoded_xor_comm = EVMSerializableType(index.xor_comm).to_bytes();
        let encoded_rot_comm = EVMSerializableType(index.rot_comm).to_bytes();

        // Encoded remaining scalars
        let encoded_shift = index
            .shift
            .into_iter()
            .flat_map(|comm| EVMSerializableType(comm).to_bytes())
            .collect();
        let encoded_w = EVMSerializableType(index.w.clone().into_inner()).to_bytes();
        let encoded_endo = EVMSerializableType(index.endo).to_bytes();

        [
            encoded_optional_field_flags,
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
            encoded_rot_comm,
            encoded_shift,
            encoded_w,
            // lookup_index
            encoded_endo,
        ]
        .concat()
    }
}
