use ark_serialize::CanonicalSerialize;
use mina_hasher::Fp;

pub fn from_str(s: &str) -> Result<Fp, ()> {
    if s.is_empty() {
        return Err(());
    }

    if s == "0" {
        return Ok(Fp::from(0u8));
    }

    let mut res = Fp::from(0u8);

    let ten = Fp::from(10u8);

    let mut first_digit = true;

    for c in s.chars() {
        match c.to_digit(10) {
            Some(c) => {
                if first_digit {
                    if c == 0 {
                        return Err(());
                    }

                    first_digit = false;
                }

                res = res * &ten;
                let digit = Fp::from(u64::from(c));
                res = res + &digit;
            }
            None => {
                return Err(());
            }
        }
    }
    Ok(res)
    //if res.0 > ark_ff::FpParameters::MODULUS {
    //    Err(())
    //} else {
    //    Ok(res)
    //}
}

pub fn to_bytes(f: &Fp) -> Vec<u8> {
    let mut bytes: Vec<u8> = vec![];
    f.serialize(&mut bytes).expect("Failed to serialize field");

    bytes.into_iter().rev().collect()
}
