use axum::{extract::Path, routing::get, Router};
use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<(), String> {
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect("postgres://postgres:password@localhost/test")
        .await
        .map_err(|err| format!("Could not create a connection pool for Postgres: {err}"))?;

    // build our application with a route
    let app = Router::new()
        .route("/", get(root))
        .route("/balance/:public_key", get(balance));

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    axum::serve(listener, app)
        .await
        .map_err(|err| format!("Could not run server: {err}"))
}

async fn root() -> &'static str {
    "Hello, World!"
}

async fn balance(Path(public_key): Path<String>) -> String {
    public_key
}
