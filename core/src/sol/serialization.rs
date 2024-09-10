use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use mina_curves::pasta::Fp;
use mina_p2p_messages::v2::{
    DataHashLibStateHashStableV1, LedgerHash, MinaBaseLedgerHash0StableV1, StateHash,
};
use serde::{Deserialize, Serialize};

/// Serialization to bytes for simple types that need to be deserialized in Ethereum.
/// More complex structures, like an [`MinaAccountValidation::Account`], may use Solidity's ABI Encoding.
pub struct SolSerialize;

impl serde_with::SerializeAs<StateHash> for SolSerialize {
    fn serialize_as<S>(val: &StateHash, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let bytes: [u8; 32] = val
            .0
            .as_ref()
            .try_into()
            .map_err(serde::ser::Error::custom)?;
        bytes.serialize(serializer)
    }
}

impl<'de> serde_with::DeserializeAs<'de, StateHash> for SolSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<StateHash, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        let bigint = bigint::BigInt::new(bytes.into());
        Ok(StateHash::from(DataHashLibStateHashStableV1(bigint)))
    }
}

impl serde_with::SerializeAs<LedgerHash> for SolSerialize {
    fn serialize_as<S>(val: &LedgerHash, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let bytes: [u8; 32] = val
            .0
            .as_ref()
            .try_into()
            .map_err(serde::ser::Error::custom)?;
        bytes.serialize(serializer)
    }
}

impl<'de> serde_with::DeserializeAs<'de, LedgerHash> for SolSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<LedgerHash, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        let bigint = bigint::BigInt::new(bytes.into());
        Ok(LedgerHash::from(MinaBaseLedgerHash0StableV1(bigint)))
    }
}

impl serde_with::SerializeAs<Fp> for SolSerialize {
    fn serialize_as<S>(val: &Fp, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut bytes = Vec::with_capacity(32);
        val.serialize(&mut bytes)
            .map_err(serde::ser::Error::custom)?;
        let bytes: [u8; 32] = bytes.try_into().map_err(|_| {
            serde::ser::Error::custom("failed to convert byte vector into 32 byte array")
        })?;
        bytes.serialize(serializer)
    }
}

impl<'de> serde_with::DeserializeAs<'de, Fp> for SolSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<Fp, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        Fp::deserialize(&mut &bytes[..]).map_err(serde::de::Error::custom)
    }
}
