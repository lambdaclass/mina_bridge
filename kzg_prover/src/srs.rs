use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct SRS {
    pub g: Vec<String>,
    pub h: String,
}

impl From<&str> for SRS {
    fn from(s: &str) -> Self {
        let v: SRS = serde_json::from_str(s).unwrap();
        v
    }
}

#[cfg(test)]
mod test {

    #[test]
    fn test_parse_json() {
        let s = std::fs::read_to_string("./test_data/srs.json").unwrap();
        let cs = super::SRS::from(s.as_str());
        println!("{:?}", cs);
    }
}
