use ark_ec::short_weierstrass_jacobian::GroupAffine;
use poly_commitment::pairing_proof::PairingProof;

type BaseField = ark_bn254::Fq;
type KZGProof = PairingProof<ark_ec::bn::Bn<ark_bn254::Parameters>>;
type G1Point = GroupAffine<ark_bn254::g1::Parameters>;

struct G1PointSchema {
    x: BaseField,
    y: BaseField,
}

impl From<G1Point> for G1PointSchema {
    fn from(value: G1Point) -> Self {
        if value.infinity {
            G1PointSchema {
                x: BaseField::from(0),
                y: BaseField::from(0),
            }
        } else {
            let G1Point { x, y, .. } = value;
            G1PointSchema { x, y }
        }
    }
}
