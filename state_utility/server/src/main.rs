use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};

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
        .route("/balance/:public_key", get(balance))
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

async fn balance(
    State(pool): State<Pool<Postgres>>,
    Path(public_key): Path<String>,
) -> Result<Json<String>, String> {
    let row: (String,) = sqlx::query_as(&format!(
        "SELECT value FROM public_keys WHERE value = '{public_key}';"
    ))
    .fetch_one(&pool)
    .await
    .map_err(|err| format!("Could not query the database: {err}"))?;

    Ok(Json(row.0))
}
