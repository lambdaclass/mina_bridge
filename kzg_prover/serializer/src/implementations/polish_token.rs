use kimchi::circuits::expr::PolishToken;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::BN254PolishToken,
};

impl EVMSerializable for EVMSerializableType<Vec<BN254PolishToken>> {
    fn to_bytes(self) -> Vec<u8> {
        let encoded_variants = vec![];
        let encoded_len = EVMSerializableType(self.0.len()).to_bytes();

        for token in self.0.iter() {
            let mut token_id;
            let token_id = match token {
                PolishToken::Alpha => token_id = 0,
                PolishToken::Beta => token_id = 1,
                PolishToken::Gamma => token_id = 2,
                PolishToken::JointCombiner => token_id = 3,
                PolishToken::EndoCoefficient => token_id = 4,
                PolishToken::Mds { row, col } => {
                    token_id = 5;
                },
                PolishToken::Literal => token_id = 6,
                PolishToken::Cell => token_id = 7,
                PolishToken::Dup => token_id = 8,
                PolishToken::Pow => token_id = 9,
                PolishToken::Add => token_id = 10,
                PolishToken::Mul => token_id = 11,
                PolishToken::Sub => token_id = 12,
                PolishToken::VanishesOnZeroKnowledgeAndPreviousRows => token_id = 13,
                PolishToken::UnnormalizedLagrangeBasis => token_id = 14,
                PolishToken::Store => token_id = 15,
                PolishToken::Load => token_id = 16,
                _ => unimplemented!(),
            };
            encoded_variants.push(token_id);
        }

        [encoded_len, encoded_variants].concat()
    }
}
