use serde::Deserialize;
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
    //pub token_symbol: string::ByteString,
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

#[cfg(test)]
mod test {
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
}
