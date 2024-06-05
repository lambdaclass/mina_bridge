/// Newtype for types that can be serialized into bytes and sent directly to
/// smart contract functions of the verifier.
pub struct EVMSerializableType<T>(pub T);

/// Trait for types that can be serialized into bytes and sent directly to
/// smart contract functions of the verifier.
pub trait EVMSerializable {
    fn to_bytes(self) -> Vec<u8>;
}
