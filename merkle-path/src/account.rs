use mina_p2p_messages::v2::MinaBaseAccountBinableArgStableV2;

pub fn query_account(public_key: &str) -> MinaBaseAccountBinableArgStableV2 {
    let body = format!(
        "{{\"query\": \"{{
                account(publicKey: \\\"{public_key}\\\") {{
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
    serde_json::from_str(&res).unwrap()
}
