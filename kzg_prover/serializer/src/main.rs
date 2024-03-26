use std::fs;

use serializer::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::{BN254PairingProof, BaseField, G1Point, ScalarField},
};

fn main() {
    generate_solidity_test_data();
}

fn generate_solidity_test_data() {
    let pairing_proof = BN254PairingProof {
        quotient: G1Point::new(BaseField::from(1), BaseField::from(2), false),
        blinding: ScalarField::from(1),
    };

    fs::write(
        "../../eth_verifier/unit_test_data/pairing_proof.bin",
        EVMSerializableType(pairing_proof).to_bytes(),
    ).unwrap();
}
