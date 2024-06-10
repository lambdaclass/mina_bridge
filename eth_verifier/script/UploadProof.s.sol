// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";

contract UploadProof is Script {
    bytes linearization_literals_serialized;
    bytes proof_hash_serialized;
    bytes prover_proof_serialized;
    bytes merkle_root_serialized;

    function run() public {
        linearization_literals_serialized = vm.readFileBinary("linearization_literals.bin");
        proof_hash_serialized = vm.readFileBinary("proof_hash.bin");
        prover_proof_serialized = vm.readFileBinary("prover_proof.bin");
        merkle_root_serialized = vm.readFileBinary("merkle_root.bin");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address verifierAddress = vm.envAddress("CONTRACT_ADDRESS");
        KimchiVerifier verifier = KimchiVerifier(verifierAddress);

        verifier.store_literal_tokens(linearization_literals_serialized);
        verifier.store_proof_hash(proof_hash_serialized);
        verifier.store_prover_proof(prover_proof_serialized);
        verifier.store_potential_merkle_root(merkle_root_serialized);

        vm.stopBroadcast();
    }
}
