use serde::{Deserialize, Serialize};

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct StateProof {
    pub proof: Proof,
}

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct Proof {
    pub openings: Openings,
}

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct Openings {
    pub proof: OpeningProof,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OpeningProof {
    pub lr: Vec<((String, String), (String, String))>,
    pub z_1: String,
    pub z_2: String,
    pub delta: (String, String),
    pub sg: (String, String),
}

impl Default for OpeningProof {
    fn default() -> Self {
        Self {
            lr: vec![
                (
                    (
                        "0xc92eea16213da7d6be4058252940ec92dfa1ad8679844b6d810c10b07eb4f20d"
                            .to_string(),
                        "0x0adfc94cb948f0d71ff28f342ac58d5a0004fa0e194b93f88d0b668b2b20ca02"
                            .to_string(),
                    ),
                    (
                        "0x713ae350b4b3acb93126c8a0d5b09823b9b88ccd4b56ba88be97f8d47e07e52b"
                            .to_string(),
                        "0x41b5e4091404d01b954970737297f2bd68a64dd1275f038a63561fcd060db716"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x020d563aeec5fe3fa7db098720c40d62855640e5aed5f0292f3eefc97eb5443f"
                            .to_string(),
                        "0x23df927368849ac9b6ec45d0049496afb3bdada0d68966a1ebd76f63c1cd370b"
                            .to_string(),
                    ),
                    (
                        "0xf3692bdf550241f9565eb3ada08d9f909a00a39dbc9a4fd7d3e78276bcaa2c3a"
                            .to_string(),
                        "0xb8c5f8b96587a7f0f3e37d044f40db9de0b8b0cfc270b39cde3326865af92d1a"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x0991e04448bb832e98a939f377002a1bd275d408f0318e975aba57f2b5aed304"
                            .to_string(),
                        "0x6166130b89c7f4928e65f6cfd456f05ad89a4d2dfecd0fb3f70ffa66bc1e770c"
                            .to_string(),
                    ),
                    (
                        "0x6dfd3c9ffae972a286449988d458726e6495c2054e98448cbe1eb9c4ea354420"
                            .to_string(),
                        "0xad2340505631b90dfba5479d80bf3091a59cbd41e86eabd5aa1ea4c23ad05320"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x49b67f8562d5e299a8f9f13618706d9484972058c5cf1fc8eeca96c1a1532a0d"
                            .to_string(),
                        "0x83714b824bbd26a46f8fefa967c862ddb9d846c20e79b5f6043a5cd2389f1323"
                            .to_string(),
                    ),
                    (
                        "0x6df0be3227dafd6ae93577249ebb00cd2bee1ace03841f594d95d9c153bea70d"
                            .to_string(),
                        "0x009dca12a74994d035ee8ec294c989c0a6a0643080df1e255db9d1671fb0321e"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xab70f69b08b15f624bd1f408b5a4f327e4dadeafe4100950f7a2ba454a363a31"
                            .to_string(),
                        "0x2d7bb08977adb4106b621f465d4aeb86a2b6cf8409567a5fc0acdd90a3c7e436"
                            .to_string(),
                    ),
                    (
                        "0xfa5e91087940249068fa5dba2926645091da5cc6a9f02fa8adcb6d1e4ffc981a"
                            .to_string(),
                        "0xa42cb4a416d407bdebd335223ed1d1b6276fd4279aa73b8aeae45026b4c4ca04"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x325e1268923b7bb29c686a4f5a2cd2b0d365f4166d93bfa7c76f91a26af8bb01"
                            .to_string(),
                        "0xe3ccf6fc9892395c691c01fc5b68a58a1d1349da42b89888a86d595c6b920d0d"
                            .to_string(),
                    ),
                    (
                        "0x84f151f3a5f7ada9ca820b444a819a22f26fbe28eca08c188c0ce32725d14f2b"
                            .to_string(),
                        "0x3c315693cc0423a37c851aa0b5b2a1dbd642496cdb2d97e886f066f215395038"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xdaea6764c5091cb7c4ebfea4776567e35f9aba1631446036569a9eab4720fc20"
                            .to_string(),
                        "0x2eb4e7ee0a1570aa11eaa3703e611967fe394b396a6072f78a2b0199bb05a427"
                            .to_string(),
                    ),
                    (
                        "0x0555540ac70319cc68e2eb9c872d172f57dbd42559e85833bca83683c1337328"
                            .to_string(),
                        "0x871db7d4428e79d8371d752afa399f19bce66bad0fa3f32f58a0dae6a53deb04"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xde289cccf5b6610f1491bd98e3563520d26f40ac462c31a0257a219e2d2a5e06"
                            .to_string(),
                        "0x1c932942b94189cdbb37b1945108936df6be4bb155491a022862dd8f2e92053f"
                            .to_string(),
                    ),
                    (
                        "0xf9f3e46c9bafbb838e9466a3fad4a65a49ad948bb7a1caa9c672f4d8c3a5a505"
                            .to_string(),
                        "0x9ce8b2528262da991b854f71511b0fa7aa2c42057fd723d58ba5589e0a5d0f22"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xa4a095f056d6f9afe82aa43a8967da446427c71328bc05ae14b0572d6a7d9612"
                            .to_string(),
                        "0x092772a7cf713ffbd984305ed72ff80c0b26764aeef7d37e9d68a6d4ac3ba53c"
                            .to_string(),
                    ),
                    (
                        "0x4428ff05720c578d6b9b7975b649fe019ea1502aea1988a62b1bf5f01de85833"
                            .to_string(),
                        "0x3baa552d0e268b2949b778ea49c050ece01b0500876e6b03267e368ee7ec6e34"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xe89f560161d84f4e4129219d61c7848c082e9ff006858d2b82a885a181e3bf22"
                            .to_string(),
                        "0x82a6a500cc419d089f060c89ceb3b584090dfc25c53e67c324732d9df4f7cd13"
                            .to_string(),
                    ),
                    (
                        "0x39ca01e48df6c8ea6c0213bf6fe3f558b01c97192652dd457121c40a3d4d6706"
                            .to_string(),
                        "0xf17d572e18fbd94f2eef5426715daf0e16a19e213a14402ac36c4bf9b876bb33"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x053e28e77bb78fd9ed8c3715337911189b14b112c9ae7b7430ea145befbe8b2a"
                            .to_string(),
                        "0x286ae3cc877d950cf1134fa3882b4fa49e401dfce7a7803ba55be471bc579513"
                            .to_string(),
                    ),
                    (
                        "0xea0a827a438b46d44c4f57f3569194777b3f6eecfe15fef11bae4a6deebfda3f"
                            .to_string(),
                        "0x6cb99c1892dbce04da8c063522fea88553d77b7424e4d9661610e853b1307433"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xa3dc3fdac284f2d42e8518e95585adb49278988aadf645eb310ede1e35918b1d"
                            .to_string(),
                        "0x3c38f7e538440b254d44e1d5228e0f3958ffd438ae0f8102efd9436bbc1eb839"
                            .to_string(),
                    ),
                    (
                        "0xb6469e86b5d427dddefebf986d84d51502b4ce513f3c6e70d160287e5bd2350f"
                            .to_string(),
                        "0x53e87e7310855e181bf3290073f87fad2b38b8061eb06bfb33c4a79d7965df01"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0xb7db26744f3fe63b2f2135b729e4600b60a7dd32cb8604e6f23d14cc7cd8a402"
                            .to_string(),
                        "0x18370007e45f2ea7f23be2b0ac0c1fcfba6681c93f5bd59f7e00a16169ae5700"
                            .to_string(),
                    ),
                    (
                        "0x26f6dc9cea00748a7b8d72c32464d16cb134046c1b4d5c655ff29ce7d994ff13"
                            .to_string(),
                        "0xbe2ce9ac32c7ae0fe12ef4a676a3d75ed7fac48267d24ff6049ea05b6cf83325"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x18db1780253c5694aedf227e981dd4678cc72d6fd9c3910aee476a29579df33f"
                            .to_string(),
                        "0x38243af32543a107311fa0f80150b530640f1d18b549794b1346d451c71cbf3d"
                            .to_string(),
                    ),
                    (
                        "0x7defe22533d77441d2fba1f80206983257155f2939e1f33219a48792635b5518"
                            .to_string(),
                        "0x6ba76560809fc17214c3d990e7ef769ebd3b679626bf62ed6a32ca8275e60f22"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x51c16ab705c66cf8ed3929e8c9171d03c7287e7fa69083b972f4bcb56efe3307"
                            .to_string(),
                        "0x0f6895f46ae9fd8f497d0db43d10a57fcbdc042745c34e9ed7e4a79d24170e3c"
                            .to_string(),
                    ),
                    (
                        "0xad7ddfa6602ba96c29f159f5be08be59b003c80ca7af8f229b921c879ed73f0a"
                            .to_string(),
                        "0x7a06a8fdf735f8715cd14ff5d692ae4d83edc64e89b5d31ebd63823eb26d9e33"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x3a85ae5da96d3651211e6289ba841fa679646de128607ac4278313ff4691ef14"
                            .to_string(),
                        "0x08c9cc2289735bbf4c6fd34a0b7e903bba97ea485d0146e43bd6efbd95799928"
                            .to_string(),
                    ),
                    (
                        "0x0c6237fab519edaeead053eaab2c1dacc7110e297440ed8d4d774a7bff62530a"
                            .to_string(),
                        "0xa314a73c2c407c1ca4fbfcb524ca7e695a6591b88bcb0e43a16b8ff247972f0e"
                            .to_string(),
                    ),
                ),
                (
                    (
                        "0x04005795294886bdc9011a886c101febd85df2500829ce11c6d87f86eee53119"
                            .to_string(),
                        "0x0d454f37d30552daed06872c4312d94fcca34241a0c684e5067420fb5ee84c23"
                            .to_string(),
                    ),
                    (
                        "0xc0ff61ce5b0ade9573ab7a063f0cb024d7ea4f9cc4d5c0a41da4a4a8ab4c863e"
                            .to_string(),
                        "0xe959d22cf121d90f1735c89c44e998359811ebb3cfd0b0684cf7f7de071b3d0d"
                            .to_string(),
                    ),
                ),
            ],
            z_1: "0xae391bae81abfa6e07ecf3e8fe4acce3e452b12fb3c69f5d1040b7ff9cfa592c".to_string(),
            z_2: "0x954d6b9b9e887b7d7c31516bbf8d7e066baf076de10b5ac39a12fedec8fec425".to_string(),
            delta: (
                "0x0d1442f65d271e8f3147ba03f39649de3148851d32655beff7f65429f5755a0c".to_string(),
                "0xdb5ecef04bf2858b81aa22faea1311328cfe76930d1baa5ef1beff1c40398a31".to_string(),
            ),
            sg: (
                "0xffdf3c3f5fd645d68ebf5f896e412d10ea4a70d973ff7dc26e802dd1409c9728".to_string(),
                "0x36ada57da4fc8879a15d03a45e87d3ae0de8c6da0158113703a34c421a895d25".to_string(),
            ),
        }
    }
}
