use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::BN254PairingProof,
};

impl EVMSerializable for EVMSerializableType<BN254PairingProof> {
    fn to_bytes(self) -> Vec<u8> {
        let BN254PairingProof { quotient, blinding } = self.0;
        let quotient = EVMSerializableType(quotient);
        let blinding = EVMSerializableType(blinding);
        [quotient.to_bytes(), blinding.to_bytes()].concat()
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
