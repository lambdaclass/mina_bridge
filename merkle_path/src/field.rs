use ark_serialize::CanonicalSerialize;
use mina_hasher::Fp;

pub fn from_str(s: &str) -> Result<Fp, String> {
    if s.is_empty() {
        return Err("Field string is empty".to_owned());
    }

    if s == "0" {
        return Ok(Fp::from(0u8));
    }

    let mut res = Fp::from(0u8);

    let ten = Fp::from(10u8);

    let mut first_digit = true;

    for c in s.chars() {
        let c_digit = c.to_digit(10).ok_or("Digit is not decimal".to_owned())?;

        if first_digit {
            if c_digit == 0 {
                return Err("First digit is zero".to_owned());
            }

            first_digit = false;
        }

        res *= &ten;
        let digit = Fp::from(u64::from(c_digit));
        res += &digit;
    }
    Ok(res)
}

pub fn to_bytes(f: &Fp) -> Vec<u8> {
    let mut bytes: Vec<u8> = vec![];
    f.serialize(&mut bytes).expect("Failed to serialize field");

    bytes.into_iter().rev().collect()
}
