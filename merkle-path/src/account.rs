use binprot::{BinProtRead, BinProtWrite};
use mina_p2p_messages::{
    bigint::BigInt,
    string,
    v2::{
        CurrencyAmountStableV1, CurrencyBalanceStableV1, DataHashLibStateHashStableV1,
        MinaBaseAccountBinableArgStableV2, MinaBaseAccountTimingStableV2,
        MinaBasePermissionsAuthRequiredStableV2, MinaBasePermissionsStableV2,
        MinaBaseReceiptChainHashStableV1, StateHash,
        UnsignedExtendedUInt32StableV1, UnsignedExtendedUInt64Int64ForVersionTagsStableV1,
    },
    versioned::Versioned,
};
use reqwest::header::CONTENT_TYPE;
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use serde_enum_str::{Deserialize_enum_str, Serialize_enum_str};
use std::fmt::Debug;

#[derive(Deserialize)]
struct Response {
    pub data: Data,
}

#[derive(Deserialize)]
struct Data {
    pub account: Account,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct Account {
    pub public_key: String,
    pub token_id: String,
    pub token_symbol: string::ByteString,
    pub balance: Balance,
    pub nonce: String,
    pub receipt_chain_hash: String,
    pub delegate: Option<String>,
    pub voting_for: String,
    pub permissions: Permissions,
}

#[derive(Deserialize, Debug)]
struct Balance {
    pub total: String,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct Permissions {
    pub edit_state: PermissionType,
    pub access: PermissionType,
    pub send: PermissionType,
    pub receive: PermissionType,
    pub set_delegate: PermissionType,
    pub set_permissions: PermissionType,
    pub set_verification_key: SetVerificationKey,
    pub set_zkapp_uri: PermissionType,
    pub edit_action_state: PermissionType,
    pub set_token_symbol: PermissionType,
    pub increment_nonce: PermissionType,
    pub set_voting_for: PermissionType,
    pub set_timing: PermissionType,
}

#[derive(Serialize_enum_str, Deserialize_enum_str, Debug)]
enum PermissionType {
    #[serde(rename = "None")]
    None,
    #[serde(rename = "Either")]
    Either,
    #[serde(rename = "Proof")]
    Proof,
    #[serde(rename = "Signature")]
    Signature,
    #[serde(rename = "Impossible")]
    Impossible,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct SetVerificationKey {
    auth: PermissionType,
    txn_version: String,
}

impl From<Account> for MinaBaseAccountBinableArgStableV2 {
    fn from(value: Account) -> Self {
        println!("{:?}", value);
        Self {
            public_key: deserialize_str(&value.public_key),
            token_id: deserialize_str(&value.token_id),
            token_symbol: value.token_symbol,
            balance: CurrencyBalanceStableV1(CurrencyAmountStableV1(
                UnsignedExtendedUInt64Int64ForVersionTagsStableV1(
                    value.balance.total.parse::<u64>().unwrap().into(),
                ),
            )),
            nonce: UnsignedExtendedUInt32StableV1(value.nonce.parse::<u32>().unwrap().into()),
            receipt_chain_hash: deserialize_receipt_chain_hash(&value.receipt_chain_hash),
            delegate: value
                .delegate
                .and_then(|delegate| Some(deserialize_str(&delegate))),
            voting_for: deserialize_state_hash(&value.voting_for),
            timing: MinaBaseAccountTimingStableV2::Untimed,
            permissions: value.permissions.into(),
            zkapp: None,
        }
    }
}

fn deserialize_str<T>(input: &str) -> T
where
    T: Serialize + DeserializeOwned + BinProtRead + BinProtWrite + Debug,
{
    serde_json::from_value(serde_json::json!(input)).unwrap()
}

fn deserialize_receipt_chain_hash(b58: &str) -> MinaBaseReceiptChainHashStableV1 {
    let mut receipt_chain_hash_bytes = [0_u8; 32];

    let receipt_chain_hash_vec = bs58::decode(b58).into_vec().unwrap();
    // We are assuming we have to remove the first 6 bytes from the decoded hash
    receipt_chain_hash_bytes.copy_from_slice(&receipt_chain_hash_vec[6..]);

    MinaBaseReceiptChainHashStableV1(BigInt::new(Box::new(receipt_chain_hash_bytes)))
}

/**
    Like `StateHash::from_str` but it avoids checking payload version. This is because `openmina`
    only allows payload version to be `16` and the Mina node contains accounts with different values
    for the payload version.
*/
fn deserialize_state_hash(b58: &str) -> StateHash {
    let state_hash_ocaml = bs58::decode(b58).into_vec().unwrap();
    let state_hash_bytes =
        Versioned::<DataHashLibStateHashStableV1, 1>::binprot_read(&mut &state_hash_ocaml[1..])
            .unwrap();

    DataHashLibStateHashStableV1::from(state_hash_bytes).into()
}

impl From<Permissions> for MinaBasePermissionsStableV2 {
    fn from(value: Permissions) -> Self {
        Self {
            edit_state: value.edit_state.into(),
            access: value.access.into(),
            send: value.send.into(),
            receive: value.receive.into(),
            set_delegate: value.set_delegate.into(),
            set_permissions: value.set_permissions.into(),
            set_verification_key: (
                value.set_verification_key.auth.into(),
                UnsignedExtendedUInt32StableV1(
                    value
                        .set_verification_key
                        .txn_version
                        .parse::<u32>()
                        .unwrap()
                        .into(),
                ),
            ),
            set_zkapp_uri: value.set_zkapp_uri.into(),
            edit_action_state: value.edit_action_state.into(),
            set_token_symbol: value.set_token_symbol.into(),
            increment_nonce: value.increment_nonce.into(),
            set_voting_for: value.set_voting_for.into(),
            set_timing: value.set_timing.into(),
        }
    }
}

impl From<PermissionType> for MinaBasePermissionsAuthRequiredStableV2 {
    fn from(value: PermissionType) -> Self {
        match value {
            PermissionType::Signature => Self::Signature,
            PermissionType::None => Self::None,
            PermissionType::Either => Self::Either,
            PermissionType::Proof => Self::Proof,
            PermissionType::Impossible => Self::Impossible,
        }
    }
}

pub fn query_account(public_key: &str) -> MinaBaseAccountBinableArgStableV2 {
    let body = format!(
        "{{\"query\": \"{{
                account(publicKey: \\\"{public_key}\\\") {{
                    publicKey
                    tokenId
                    tokenSymbol
                    nonce
                    receiptChainHash
                    delegate
                    votingFor
                    timing {{
                        cliffAmount
                        cliffTime
                        initialMinimumBalance
                        vestingIncrement
                        vestingPeriod
                    }}
                    permissions {{
                        access
                        editActionState
                        editState
                        incrementNonce
                        receive
                        send
                        setDelegate
                        setPermissions
                        setTiming
                        setTokenSymbol
                        setVerificationKey {{
                        auth
                        txnVersion
                        }}
                        setVotingFor
                        setZkappUri
                    }}
                    zkappState
                    zkappUri
                    verificationKey
                    balance {{
                        total
                    }}
                }}
        }}\"}}"
    );
    println!("body: {}", body);
    let client = reqwest::blocking::Client::new();
    let res = client
        .post("http://5.9.57.89:3085/graphql")
        .header(CONTENT_TYPE, "application/json")
        .body(body)
        .send()
        .unwrap()
        .text()
        .unwrap();
    println!("res: {}", res);
    let deserialied_res: Response = serde_json::from_str(&res).unwrap();
    let deserialized_account = deserialied_res.data.account;

    deserialized_account.into()
}

#[cfg(test)]
mod test {
    use std::str::from_utf8;

    use mina_p2p_messages::{bigint::BigInt, v2::MinaBaseReceiptChainHashStableV1};
    use reqwest::header::CONTENT_TYPE;
    use serde::Deserialize;

    use crate::account::deserialize_receipt_chain_hash;

    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct ReceiptChainHashResponse {
        pub data: ReceiptChainHashData,
    }

    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct ReceiptChainHashData {
        pub account: ReceiptChainHashAccount,
    }

    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct ReceiptChainHashAccount {
        pub receipt_chain_hash: String,
    }

    #[test]
    fn test_deser_receipt_chain_hash() {
        let body = format!(
            "{{\"query\": \"{{
                    account(publicKey: \\\"B62qk8PgLSaL6DJKniMXwh6zePZP3q8vRLQDw1prXyu5YqZZMMemSQ2\\\") {{
                        receiptChainHash
                    }}
            }}\"}}"
        );
        println!("body: {}", body);
        let client = reqwest::blocking::Client::new();
        let res = client
            .post("http://5.9.57.89:3085/graphql")
            .header(CONTENT_TYPE, "application/json")
            .body(body)
            .send()
            .unwrap()
            .text()
            .unwrap();
        println!("res: {}", res);
        let deserialized_res: ReceiptChainHashResponse = serde_json::from_str(&res).unwrap();
        let receipt_chain_hash =
            deserialize_receipt_chain_hash(&deserialized_res.data.account.receipt_chain_hash);

        println!("{:?}", receipt_chain_hash);
    }
}
