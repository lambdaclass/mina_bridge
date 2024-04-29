use kimchi::circuits::{
    expr::{Column, PolishToken, Variable},
    gate::{CurrOrNext, GateType},
    lookup::lookups::LookupPattern,
};

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::BN254PolishToken,
};

impl EVMSerializable for EVMSerializableType<Vec<BN254PolishToken>> {
    fn to_bytes(self) -> Vec<u8> {
        // The idea is to have different bytes arrays. The first one
        // will contain every token variant, then we'll have other
        // arrays for the data associated to each variant, if any.

        let mut encoded_variants: Vec<u8> = vec![];

        // encoded data:
        let mut encoded_mds = vec![];
        let mut encoded_literals = vec![];
        let mut encoded_pows = vec![];
        let mut encoded_offsets = vec![];
        let mut encoded_loads = vec![];

        for token in self.0.iter() {
            // We'll save one byte per token to identify each variant. The
            // value of this byte will be `token_id`.
            let mut token_id: u8;

            match token {
                PolishToken::Alpha => token_id = 0,
                PolishToken::Beta => token_id = 1,
                PolishToken::Gamma => token_id = 2,
                PolishToken::JointCombiner => token_id = 3,
                PolishToken::EndoCoefficient => token_id = 4,
                PolishToken::Mds { row, col } => {
                    token_id = 5;
                    encoded_mds.extend(EVMSerializableType(*row).to_bytes());
                    encoded_mds.extend(EVMSerializableType(*col).to_bytes());
                }
                PolishToken::Literal(literal) => {
                    token_id = 6;
                    encoded_literals.extend(EVMSerializableType(*literal).to_bytes());
                }
                PolishToken::Dup => token_id = 7,
                PolishToken::Pow(pow) => {
                    token_id = 8;
                    encoded_pows.extend(EVMSerializableType(*pow).to_bytes());
                }
                PolishToken::Add => token_id = 9,
                PolishToken::Mul => token_id = 10,
                PolishToken::Sub => token_id = 11,
                PolishToken::VanishesOnZeroKnowledgeAndPreviousRows => token_id = 12,
                PolishToken::UnnormalizedLagrangeBasis(offset) => {
                    token_id = 13;
                    encoded_offsets.extend(EVMSerializableType(*offset).to_bytes());
                }
                PolishToken::Store => token_id = 14,
                PolishToken::Load(index) => {
                    token_id = 15;
                    encoded_loads.extend(EVMSerializableType(*index).to_bytes());
                }
                PolishToken::Cell(Variable { col, row }) => {
                    token_id = 16;
                    // Cell variants have a more complex structure, because of
                    // nested enums. We'll encode its id in a different way.
                    //
                    // A cell variant represents a variable from a constraint, by specifying
                    // its column and relative row.
                    //
                    // We'll use the most significant bit of the id for encoding the row:
                    let row_flag = match row {
                        CurrOrNext::Curr => 0,
                        CurrOrNext::Next => 1,
                    };
                    token_id |= row_flag << 7;

                    // then we encode the column as if they were different
                    // polish token variants (effectively flattening out the
                    // nested enums), we just need to add to the initialized token:
                    token_id += match col {
                        Column::Witness(i) => *i, // i <= 14
                        Column::Z => 15,
                        Column::LookupSorted(i) => 16 + i, // i <= 4
                        Column::LookupAggreg => 21,
                        Column::LookupTable => 22,
                        Column::LookupKindIndex(LookupPattern::Xor) => 23,
                        Column::LookupKindIndex(LookupPattern::Lookup) => 24,
                        Column::LookupKindIndex(LookupPattern::RangeCheck) => 25,
                        Column::LookupKindIndex(LookupPattern::ForeignFieldMul) => 26,
                        Column::LookupRuntimeSelector => 27,
                        Column::LookupRuntimeTable => 28,
                        Column::Index(GateType::Zero) => 29,
                        Column::Index(GateType::Generic) => 30,
                        Column::Index(GateType::Poseidon) => 31,
                        Column::Index(GateType::CompleteAdd) => 32,
                        Column::Index(GateType::VarBaseMul) => 33,
                        Column::Index(GateType::EndoMul) => 34,
                        Column::Index(GateType::EndoMulScalar) => 35,
                        Column::Index(GateType::Lookup) => 36,
                        Column::Index(GateType::RangeCheck0) => 37,
                        Column::Index(GateType::RangeCheck1) => 38,
                        Column::Index(GateType::ForeignFieldAdd) => 39,
                        Column::Index(GateType::ForeignFieldMul) => 40,
                        Column::Index(GateType::Xor16) => 41,
                        Column::Index(GateType::Rot64) => 42,
                        Column::Coefficient(i) => 43 + i, // i <= 14
                        Column::Permutation(i) => 58 + i, // i <= 5
                        _ => unimplemented!(),
                    } as u8
                }
                _ => unimplemented!(),
            };
            encoded_variants.push(token_id);
        }

        // Pad with zeros until bytes are multiples of 32
        if encoded_variants.len() % 32 != 0 {
            let new_len = (encoded_variants.len() / 32 + 1) * 32;
            encoded_variants.resize(new_len, 0);
        }

        let encoded_total_variants_len = EVMSerializableType(self.0.len()).to_bytes();
        // length in words
        let encoded_variants_len = EVMSerializableType(encoded_variants.len() / 32).to_bytes();
        let encoded_mds_len = EVMSerializableType(encoded_mds.len() / 32).to_bytes();
        let encoded_literals_len = EVMSerializableType(encoded_literals.len() / 32).to_bytes();
        let encoded_pows_len = EVMSerializableType(encoded_pows.len() / 32).to_bytes();
        let encoded_loads_len = EVMSerializableType(encoded_loads.len() / 32).to_bytes();
        let encoded_offsets_len = EVMSerializableType(encoded_offsets.len() / 32).to_bytes();

        [
            encoded_total_variants_len,
            // variants
            encoded_variants_len,
            encoded_variants,
            // mds
            encoded_mds_len,
            encoded_mds,
            // literals
            encoded_literals_len,
            encoded_literals,
            // pows
            encoded_pows_len,
            encoded_pows,
            // loads
            encoded_loads_len,
            encoded_loads,
            // offsets
            encoded_offsets_len,
            encoded_offsets,
        ]
        .concat()
    }
}
