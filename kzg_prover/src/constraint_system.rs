use serde::Deserialize;

#[derive(Deserialize, Debug, PartialEq)]
pub struct Wire {
    pub row: usize,
    pub col: usize,
}

#[derive(Deserialize, Debug, PartialEq)]
pub struct ConstraintSystemElem {
    pub r#type: String,
    pub wires: [Wire; 7],
    pub coeffs: Vec<String>,
}

#[derive(Deserialize, Debug, PartialEq)]
pub struct ConstraintSystem(pub Vec<ConstraintSystemElem>);

impl From<&str> for ConstraintSystem {
    fn from(s: &str) -> Self {
        let v: ConstraintSystem = serde_json::from_str(s).unwrap();
        v
    }
}

#[cfg(test)]
mod test {
    use crate::constraint_system::{ConstraintSystem, ConstraintSystemElem, Wire};

    #[test]
    fn test_parse_json() {
        let cs_test = "[{\"type\":\"Generic\",\"wires\":[{\"row\":259,\"col\":0},{\"row\":0,\"col\":1},{\"row\":0,\"col\":2},{\"row\":0,\"col\":3},{\"row\":0,\"col\":4},{\"row\":0,\"col\":5},{\"row\":0,\"col\":6}],\"coeffs\":[\"1\",\"0\",\"0\",\"0\",\"0\"]}]";

        let actual_cs = ConstraintSystem::from(cs_test);

        let expected_cs = ConstraintSystem(vec![ConstraintSystemElem {
            r#type: "Generic".to_string(),
            wires: [
                Wire { row: 259, col: 0 },
                Wire { row: 0, col: 1 },
                Wire { row: 0, col: 2 },
                Wire { row: 0, col: 3 },
                Wire { row: 0, col: 4 },
                Wire { row: 0, col: 5 },
                Wire { row: 0, col: 6 },
            ],
            coeffs: vec![
                "1".to_string(),
                "0".to_string(),
                "0".to_string(),
                "0".to_string(),
                "0".to_string(),
            ],
        }]);
        assert_eq!(actual_cs, expected_cs);
    }
}
