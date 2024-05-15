use mina_p2p_messages::{
    string,
    v2::{
        CurrencyBalanceStableV1, MinaBaseAccountBinableArgStableV2, MinaBaseAccountTimingStableV2,
        MinaBasePermissionsAuthRequiredStableV2, MinaBasePermissionsStableV2,
        MinaBaseReceiptChainHashStableV1, MinaBaseZkappAccountStableV2, NonZeroCurvePoint,
        StateHash, TokenIdKeyHash, UnsignedExtendedUInt32StableV1,
    },
};
use reqwest::header::CONTENT_TYPE;
use serde::Deserialize;
use serde_enum_str::{Deserialize_enum_str, Serialize_enum_str};

#[derive(Deserialize)]
struct Response {
    pub data: Data,
}

#[derive(Deserialize)]
struct Data {
    pub account: Account,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Account {
    pub public_key: NonZeroCurvePoint,
    pub token_id: TokenIdKeyHash,
    pub token_symbol: string::ByteString,
    pub balance: CurrencyBalanceStableV1,
    pub nonce: UnsignedExtendedUInt32StableV1,
    pub receipt_chain_hash: MinaBaseReceiptChainHashStableV1,
    pub delegate: Option<NonZeroCurvePoint>,
    pub voting_for: StateHash,
    pub permissions: Permissions,
    pub zkapp: Option<MinaBaseZkappAccountStableV2>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Permissions {
    pub edit_state: PermissionType,
    pub access: PermissionType,
    pub send: PermissionType,
    pub receive: PermissionType,
    pub set_delegate: PermissionType,
    pub set_permissions: PermissionType,
    pub set_verification_key: (PermissionType, u32),
    pub set_zkapp_uri: PermissionType,
    pub edit_action_state: PermissionType,
    pub set_token_symbol: PermissionType,
    pub increment_nonce: PermissionType,
    pub set_voting_for: PermissionType,
    pub set_timing: PermissionType,
}

#[derive(Serialize_enum_str, Deserialize_enum_str)]
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

impl From<Account> for MinaBaseAccountBinableArgStableV2 {
    fn from(value: Account) -> Self {
        Self {
            public_key: value.public_key,
            token_id: value.token_id,
            token_symbol: value.token_symbol,
            balance: value.balance,
            nonce: value.nonce,
            receipt_chain_hash: value.receipt_chain_hash,
            delegate: value.delegate,
            voting_for: value.voting_for,
            timing: MinaBaseAccountTimingStableV2::Untimed,
            permissions: value.permissions.into(),
            zkapp: value.zkapp,
        }
    }
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
                value.set_verification_key.0.into(),
                UnsignedExtendedUInt32StableV1(value.set_verification_key.1.into()),
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
    use binprot::BinProtRead;
    use mina_p2p_messages::v2::MinaBaseReceiptChainHashStableV1;
    use reqwest::header::CONTENT_TYPE;
    use serde::Deserialize;

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
        let deserialied_res: ReceiptChainHashResponse = serde_json::from_str(&res).unwrap();
        let mut receipt_chain_hash_bytes =
            bs58::decode(&deserialied_res.data.account.receipt_chain_hash)
                .into_vec()
                .unwrap();

        let receipt_chain_hash =
            MinaBaseReceiptChainHashStableV1::binprot_read(&mut &receipt_chain_hash_bytes[..])
                .unwrap();

        println!("{:?}", receipt_chain_hash);
    }
}
