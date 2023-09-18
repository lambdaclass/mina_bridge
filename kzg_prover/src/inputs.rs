use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct Inputs {
    pub sg: [String; 2],
    pub z1: String,
    pub expected: [String; 2],
}

impl From<&str> for Inputs {
    fn from(s: &str) -> Self {
        let v: Self = serde_json::from_str(s).unwrap();
        v
    }
}
