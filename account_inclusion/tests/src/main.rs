fn main() {
    println!("Hello, world!");
}

/// `implied_root` in OCaml
// pub fn checked_verify_merkle_path(
//     account: &Account,
//     merkle_path: &[MerklePath],
//     w: &mut Witness<Fp>,
// ) -> Fp {
//     use crate::proofs::transaction::transaction_snark::checked_hash;
//
//     let account_hash = account.checked_hash(w);
//     let mut param = String::with_capacity(16);
//
//     merkle_path
//         .iter()
//         .enumerate()
//         .fold(account_hash, |accum, (depth, path)| {
//             let hashes = match path {
//                 MerklePath::Left(right) => [accum, *right],
//                 MerklePath::Right(left) => [*left, accum],
//             };
//
//             param.clear();
//             write!(&mut param, "MinaMklTree{:03}", depth).unwrap();
//
//             w.exists(hashes);
//             checked_hash(param.as_str(), &hashes, w)
//         })
// }

#[cfg(test)]
mod test {
    use std::str::FromStr;

    use mina_p2p_messages::{
        binprot::BinProtRead,
        v2::{LedgerHash, MerkleTreeNode, MinaBaseAccountBinableArgStableV2},
    };
    use snark::calc_merkle_root_hash;

    #[test]
    fn openmina_merkle_verifier() {
        let account = "41834e3ddf0430d377731101949ed664809eee22c373bb738ef65fb5420a112d01010000000000000000000000000000000000000000000000000000000000000000fc004cd0b50a000000009be4b7c51ed9c2e4524727805fd36f5220fbfc70a749f62623b0ed29084333200141834e3ddf0430d377731101949ed664809eee22c373bb738ef65fb5420a112d010000000000000000000000000000000000000000000000000000000000000000000300030003030303030303030300";
        let merkle_path = "234f681265c3737510214e895b5674bffdea516d954909a9acb4be7d03b708342cc6d4a10379f722f92234cfbbe0e66cd8137ad844d547f111cbcde8fa1a68bb895ad7375f813d081b79f722f95665ac78a0f61fed469dfae9aeb295753d9fb7e02ee53e42a26fcbf43882a2304f681265cf2bd61cdf52dfe52462b273465f7ee8bb43a35f63bed2a35052e208afff183e79f722f9e37c646975a5c2bc98e2a6da10fd03ecb6279ec1c108202a95ad2c938edfeb274f681265ac9909d3b4b7502e9a3032fec5e2a342cbf80cecfa3bae29359bc1907baa93014f681265104d0e2bc49061f6ba40cd4b746bd746576b58271aa0fa0e295e8f4cad5f511c79f722f97ceffcf470d927dec3102fd1a9cd22d23b3266dd732adf5e909d267091f358184f681265c31c1def8576c6f94135e03c5a2db26e8251156d8259966a49a6197d25d4552179f722f95698c974425ea8e192373c022b9eb18cc7f30490b24575ed6deb23e812c25d2c79f722f9f1e233b942ff9fafe2158982a351ab822c8fa562d56ce0038522ca5e074fce1879f722f9e0ee3e873daa198014e97ab407a5842159f516492b5c026d90babf3c95a3ce384f681265d44c78898f2503f34f2496e5bc9a46059611c38cc2bec4d2419d6675eaef491879f722f984ee4e1d78b2885f9c1d4fd7b3bf5cfd105fce2ea7c12e75c224def66ec254224f6812657a7561af106593ac709c0770f28c12e0c03a90a1ea06f625cb64f5fc06a70d1c4f6812650ab7921633ec6ddd00de1a0a6b8a251474f14ee5999dc46de1c4134808033d1d4f6812659f602224e3269ea9e3f382ef4e8700387ed33b6d507f7fa7764a2710894626274f681265af026f4946f3516799e4bddf4175d750053755384ad1bf33d1b0b1bb3b2d54034f6812658cf063d511af180f796dc98cc70994cb938b01af01aec751a128fec9f0bf09324f681265cb6690e8df94ff60f5aa938b98058acb2e6aaf4536895879d2eb52e8d63a371d4f6812657660c991bc8578dfcd1ae1312e3e7afdfacfed84baa1eff8f6488c5a23fd003d4f68126548801e1bbe51b543c4df30049d7acb74f66766531509dc31d5754b0c61cb56324f681265946ee3ae2879d186f4702f42f69d6d21b8bb8900457571f937605b9e4c7bac2c4f681265bd2f24c074ca3a8bcb3a4f639bbc28d7f739e5df01527c0672738abe55aace264f6812652990a7ea6a37cbaa56320bce1c7fad85de7af69e24db070fb935a017a9d6e4184f6812653efbd38b92831f0da62fa9c472d63bb13b4951d5f147cbaa2d7ce6605757d9324f681265db0689a205080aec5456c739b56ddc5186f4dcab3822b69b82d9dc1ad564e32c4f6812650a90c14f909bad3c62a95d1c36b383483614edd686cf91ea9956ebc7d23645274f681265837d35aa35800cc5f953f9cafaef45368c2e4c6fdfe4838dff3494daa6ede12f4f6812654c085c0e0f4093f37c1fdae0aa4bb7a76d69aa7ac01bf002d011ccca806611234f681265461a736a781d71820d9c20a450e58737feeb89fe55ec59e2683f99ecf8cc8f2e4f6812653015406217dc416ed122717d17973132187c04a850b1dc9eddcdd22a0553cc134f681265cc7561382e1457190c1a7464bd33ac44ee5efceb957ea1920e8f12160118f80a4f681265c2cbd8d1e94e0ac2774972d8b046d6b8a849dc8fe0908ac1353fe4e15b6dee264f68126560604248379091b9543457f6bf4ff4f5806b5293dd587842d0a2bbab2c71a819";
        let expected_root_hash = "jxTAZfKKDxoX4vtt68pQCWooXoVLjnfBpusaMwewrcZxsL3uWp6";

        let account = hex::decode(account).unwrap();
        let mut cursor = std::io::Cursor::new(account);
        let account = MinaBaseAccountBinableArgStableV2::binprot_read(&mut cursor).unwrap();

        let merkle_path = hex::decode(merkle_path).unwrap();
        let mut cursor = std::io::Cursor::new(merkle_path);
        let merkle_path = Vec::<MerkleTreeNode>::binprot_read(&mut cursor).unwrap();

        let root_hash = calc_merkle_root_hash(&account, &merkle_path[..]);

        let expected_root_hash = LedgerHash::from_str(expected_root_hash).unwrap().0.clone();

        assert_eq!(root_hash, expected_root_hash);
    }
}
