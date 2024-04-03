use crate::{
    serialize::{EVMSerializable, EVMSerializableType},
    type_aliases::BN254PolyComm,
};

impl EVMSerializable for EVMSerializableType<Vec<BN254PolyComm>> {
    fn to_bytes(self) -> Vec<u8> {
        self.0
            .into_iter()
            .flat_map(|p| EVMSerializableType(p).to_bytes())
            .collect()
    }
}

impl EVMSerializable for EVMSerializableType<&mut Vec<BN254PolyComm>> {
    fn to_bytes(self) -> Vec<u8> {
        self.0
            .clone()
            .into_iter()
            .flat_map(|p| EVMSerializableType(p).to_bytes())
            .collect()
    }
}
