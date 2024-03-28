use ark_ec::short_weierstrass_jacobian::GroupAffine;
use o1_utils::FieldHelpers;

use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254PolyComm, G1Point, ScalarField},
};

impl EVMSerializable for EVMSerializableType<ScalarField> {
    fn to_bytes(self) -> Vec<u8> {
        self.0.to_bytes().into_iter().rev().collect() // flip endianness
    }
}

impl EVMSerializable for EVMSerializableType<G1Point> {
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

impl EVMSerializable for EVMSerializableType<BN254PolyComm> {
    fn to_bytes(self) -> Vec<u8> {
        // We are assuming that `max_poly_size` is set so no poly gets chunked.
        // In this case there's only one point per PolyComm.
        //
        // We are also ignoring the shifted point
        if self.0.unshifted.len() != 1 {
            panic!("Tried to encode a polycomm with more (or less) than one unshifted element!");
        }
        EVMSerializableType(self.0.unshifted[0]).to_bytes()
    }
}

#[cfg(test)]
mod test {
    use crate::type_aliases::BaseField;

    use super::*;

    #[test]
    fn test_scalar_field_ser() {
        let scalar = ScalarField::from(1);
        let serialized = EVMSerializableType(scalar).to_bytes();
        assert_eq!(serialized, vec![vec![0; 31], vec![1]].concat());
    }

    #[test]
    fn test_g1_point_ser() {
        let point = G1Point::new(BaseField::from(1), BaseField::from(2), false);
        let serialized = EVMSerializableType(point).to_bytes();
        assert_eq!(
            serialized,
            vec![vec![0; 31], vec![1], vec![0; 31], vec![2]].concat()
        );
    }

    #[test]
    fn test_g1_point_at_infinity_ser() {
        let point = G1Point::new(BaseField::from(1), BaseField::from(2), true);
        let serialized = EVMSerializableType(point).to_bytes();
        assert_eq!(serialized, vec![0; 64]);
    }
}
