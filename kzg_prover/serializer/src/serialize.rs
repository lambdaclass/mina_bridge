use ark_ec::short_weierstrass_jacobian::GroupAffine;
use o1_utils::FieldHelpers;
use poly_commitment::pairing_proof::PairingProof;

pub trait EVMSerializable {
    fn to_bytes(self) -> Vec<u8>;
}

type ScalarField = ark_bn254::Fr;
type BN254PairingProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
type G1Point = GroupAffine<ark_bn254::g1::Parameters>;

struct G1PointSerializable(G1Point);
struct PairingProofSerializable(BN254PairingProof);

impl EVMSerializable for G1PointSerializable {
    fn to_bytes(self) -> Vec<u8> {
        let GroupAffine { x, y, infinity, .. } = self.0;
        if infinity {
            vec![0; 64]
        } else {
            [
                x.to_bytes().into_iter().rev().collect::<Vec<_>>(), // flip endianness
                y.to_bytes().into_iter().rev().collect::<Vec<_>>(), // flip endianness
            ]
            .concat()
        }
    }
}

impl EVMSerializable for PairingProofSerializable {
    fn to_bytes(self) -> Vec<u8> {
        let BN254PairingProof { quotient, blinding } = self.0;
        let quotient = G1PointSerializable(quotient);
        [quotient.to_bytes(), blinding.to_bytes()].concat()
    }
}

#[cfg(test)]
mod test {
    use super::*;

    type BaseField = ark_bn254::Fq;

    #[test]
    fn test_g1_point_ser() {
        let point = G1Point::new(BaseField::from(1), BaseField::from(2), false);
        let serialized = G1PointSerializable(point).to_bytes();
        assert_eq!(
            serialized,
            vec![vec![0; 31], vec![1], vec![0; 31], vec![2]].concat()
        );
    }
}
