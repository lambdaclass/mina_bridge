use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct Wire {
    pub row: u32,
    pub col: u32,
}

#[derive(Deserialize, Debug)]
pub struct ConstraintSystemElem {
    pub r#type: String,
    pub wires: Vec<Wire>,
    pub coeffs: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub struct ConstraintSystem(Vec<ConstraintSystemElem>);

impl From<&str> for ConstraintSystem {
    fn from(s: &str) -> Self {
        let v: ConstraintSystem = serde_json::from_str(s).unwrap();
        v
    }
}

#[cfg(test)]
mod test {

    #[test]
    fn test_parse_json() {
        let s = std::fs::read_to_string("./test_data/constraint_system.json").unwrap();
        let cs = super::ConstraintSystem::from(s.as_str());
        println!("{:?}", cs);
    }
}
