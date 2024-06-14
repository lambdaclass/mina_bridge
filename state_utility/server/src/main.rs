use alloy::{
    network::EthereumWallet, providers::ProviderBuilder, signers::local::PrivateKeySigner, sol,
};
use alloy_primitives::{Bytes, FixedBytes};
use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use merkle_path::{field, merkle_path::MerkleTree, serialize::EVMSerializable as _};
use reqwest::Url;
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};

sol!(
    #[sol(rpc)]
    Verifier,
    "verifier.json"
);

#[tokio::main]
async fn main() -> Result<(), String> {
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect("postgres://pguser:pguser@localhost/archive")
        .await
        .map_err(|err| format!("Could not create a connection pool for Postgres: {err}"))?;

    // build our application with a route
    let app = Router::new()
        .route("/", get(root))
        .route("/account_state/:mina_public_key/:mina_rpc_url_str/:eth_rpc_url_str/:verifier_address_str", get(account_state))
        .with_state(pool);

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    axum::serve(listener, app)
        .await
        .map_err(|err| format!("Could not run server: {err}"))
}

async fn root() -> &'static str {
    "Hello, World!"
}

async fn account_state(
    State(pool): State<Pool<Postgres>>,
    Path((mina_public_key, mina_rpc_url_str, eth_rpc_url_str, verifier_address_str)): Path<(
        String,
        String,
        String,
        String,
    )>,
) -> Result<Json<String>, String> {
    // 1) get balance
    let ret_balance = balance(pool, &mina_public_key).await?;
    let ret_string = ret_balance.0;

    // 2) get merkle proof
    let ret_merkle_proof = merkle_proof(
        &mina_public_key,
        &mina_rpc_url_str,
        &eth_rpc_url_str,
        &verifier_address_str,
    )
    .await?;
    let ret_merkle_proof_string = ret_merkle_proof.0;

    println!("{ret_string} - {ret_merkle_proof_string}");
    // return JSON
    //{
    //    "verified": true,
    //    "balance": 100
    //}
    let response = format!(r#"{{"verified": true, "balance": 200}}"#);
    Ok(Json(response))
}

async fn balance(pool: Pool<Postgres>, mina_public_key: &str) -> Result<Json<String>, String> {
    let query = "SELECT height, balance
        FROM accounts_accessed
        INNER JOIN account_identifiers ON account_identifiers.id = accounts_accessed.account_identifier_id
        INNER JOIN public_keys ON public_keys.id = account_identifiers.public_key_id
        INNER JOIN blocks ON blocks.id = accounts_accessed.block_id
        WHERE public_keys.value = $1";

    let row: (i64, String) = sqlx::query_as(query)
        .bind(mina_public_key)
        .fetch_one(&pool)
        .await
        .map_err(|err| format!("Could not query the database: {err}"))?;

    Ok(Json(row.1))
}

async fn merkle_proof(
    mina_public_key: &str,
    mina_rpc_url_str: &str,
    eth_rpc_url_str: &str,
    verifier_address_str: &str,
) -> Result<Json<String>, String> {
    let eth_rpc_url =
        Url::parse(eth_rpc_url_str).map_err(|err| format!("Could not parse RPC URL: {err}"))?;

    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .on_http(eth_rpc_url);

    let verifier_address = verifier_address_str
        .parse()
        .map_err(|err| format!("Could not parse Verifier address: {err}"))?;
    let contract = Verifier::new(verifier_address, provider);

    let merkle_tree = MerkleTree::query_merkle_path(mina_rpc_url_str, mina_public_key)?;
    let leaf_hash = field::from_str(&merkle_tree.data.account.leaf_hash)?;
    let leaf_hash_bytes = FixedBytes::from_slice(&field::to_bytes(&leaf_hash)?);
    let merkle_path_bytes =
        Bytes::copy_from_slice(&merkle_tree.data.account.merkle_path.to_bytes());

    let transaction_builder = contract.verify_account_inclusion(leaf_hash_bytes, merkle_path_bytes);
    let is_account_valid = transaction_builder
        .call()
        .await
        .map_err(|err| format!("Could not call verification method: {err}"))?
        ._0;

    let response = format!("{is_account_valid}");

    Ok(Json(response))
}
