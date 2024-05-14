use binprot::BinProtRead;

pub struct BigInt(pub [u8; 32]);

impl BinProtRead for BigInt {
    fn binprot_read<R: std::io::Read + ?Sized>(r: &mut R) -> Result<Self, binprot::Error>
    where
        Self: Sized,
    {
        let mut buf = [0; 32];
        r.read_exact(&mut buf)?;
        Ok(Self(buf))
    }
}
