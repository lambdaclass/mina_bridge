use std::array;

use kimchi::{
    circuits::{
        gate::{CircuitGate, GateType},
        wires::{Wire, PERMUTS},
    },
    o1_utils::FieldHelpers,
};
use num::BigInt;
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct SnarkyGate {
    pub r#type: String,
    pub wires: Vec<SnarkyWire>,
    pub coeffs: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SnarkyWire {
    pub col: usize,
    pub row: usize,
}

impl Into<Wire> for SnarkyWire {
    fn into(self) -> Wire {
        Wire {
            row: self.row,
            col: self.col,
        }
    }
}

impl Into<CircuitGate<ark_bn254::Fr>> for SnarkyGate {
    fn into(self) -> CircuitGate<ark_bn254::Fr> {
        let typ = if self.r#type == "Generic" {
            GateType::Generic
        } else if self.r#type == "ForeignFieldAdd" {
            GateType::ForeignFieldAdd
        } else if self.r#type == "ForeignFieldMul" {
            GateType::ForeignFieldMul
        } else if self.r#type == "Zero" {
            GateType::Zero
        } else if self.r#type == "RangeCheck0" {
            GateType::RangeCheck0
        } else if self.r#type == "RangeCheck1" {
            GateType::RangeCheck1
        } else if self.r#type == "Poseidon" {
            GateType::Poseidon
        } else {
            panic!("{} is not a valid GateType", self.r#type)
        };

        let wires: [Wire; PERMUTS] = array::from_fn(|i| self.wires[i].clone().into());
        let coeffs: Vec<ark_bn254::Fr> = self
            .coeffs
            .iter()
            .map(|coeff| {
                let coeff_bigint = coeff.parse::<BigInt>().unwrap();
                ark_bn254::Fr::from_biguint(&coeff_bigint.to_biguint().unwrap()).unwrap()
            })
            .collect();

        CircuitGate { typ, wires, coeffs }
    }
}
