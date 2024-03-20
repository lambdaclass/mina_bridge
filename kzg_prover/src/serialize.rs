use ark_ec::short_weierstrass_jacobian::GroupAffine;
use o1_utils::FieldHelpers;
use poly_commitment::pairing_proof::PairingProof;

pub trait Serializable {
    fn to_bytes(self) -> Vec<u8>;
}

type BN254PairingProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
type G1Point = GroupAffine<ark_bn254::g1::Parameters>;

struct G1PointSerializable(G1Point);
struct PairingProofSerializable(BN254PairingProof);

impl Serializable for G1PointSerializable {
    fn to_bytes(self) -> Vec<u8> {
        let GroupAffine { x, y, infinity, .. } = self.0;
        if infinity {
            vec![0; 64]
        } else {
            [x.to_bytes(), y.to_bytes()].concat()
        }
    }
}

impl Serializable for PairingProofSerializable {
    fn to_bytes(self) -> Vec<u8> {
        let BN254PairingProof { quotient, blinding } = self.0;
        let quotient = G1PointSerializable(quotient);
        [quotient.to_bytes(), blinding.to_bytes()].concat()
    }
}
