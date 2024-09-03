use mina_p2p_messages::{
    bigint,
    v2::{DataHashLibStateHashStableV1, LedgerHash, MinaBaseLedgerHash0StableV1, StateHash},
};
use serde::{Deserialize, Serialize};

use super::account_proof::AccountHash;

/// Simple serialization for types that need to be deserialized in Ethereum.
pub struct EVMSerialize;

impl serde_with::SerializeAs<StateHash> for EVMSerialize {
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

impl<'de> serde_with::DeserializeAs<'de, StateHash> for EVMSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<StateHash, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        let bigint = bigint::BigInt::new(bytes.into());
        Ok(StateHash::from(DataHashLibStateHashStableV1(bigint)))
    }
}

impl serde_with::SerializeAs<LedgerHash> for EVMSerialize {
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

impl<'de> serde_with::DeserializeAs<'de, LedgerHash> for EVMSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<LedgerHash, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        let bigint = bigint::BigInt::new(bytes.into());
        Ok(LedgerHash::from(MinaBaseLedgerHash0StableV1(bigint)))
    }
}

impl serde_with::SerializeAs<AccountHash> for EVMSerialize {
    fn serialize_as<S>(val: &AccountHash, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        val.0.serialize(serializer)
    }
}

impl<'de> serde_with::DeserializeAs<'de, AccountHash> for EVMSerialize {
    fn deserialize_as<D>(deserializer: D) -> Result<AccountHash, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes = <[u8; 32]>::deserialize(deserializer)?;
        Ok(AccountHash(bytes))
    }
}
