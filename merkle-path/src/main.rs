pub mod merkle_path;
use reqwest::header::CONTENT_TYPE;

fn main() {
    let client = reqwest::blocking::Client::new();
    let res = client
        .post("http://5.9.57.89:3085/graphql")
        .header(CONTENT_TYPE, "application/json")
        .body(
            r#"{"query": "{
            account(publicKey: \"B62qkWL1NPMtQ2WAntxi6x2FzoYR4oxLR2vmA3AjZzRyHAEWxaEfNht\") {
              merklePath { 
                  left 
                  right
              }
            }
        }"}"#,
        )
        .send()
        .unwrap()
        .text()
        .unwrap();

    println!("{}", res);
}
