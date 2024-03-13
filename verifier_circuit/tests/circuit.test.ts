import { deserOpeningProof } from '../src/serde/serde_proof';
import { TestCircuit } from '../src/test_circuit';
import testInputs from "../test_data/inputs.json";

test("Run test circuit", async () => {
    console.log("Generating Bn254 test circuit keypair...");
    let testKeypair = await TestCircuit.generateKeypair();
    let openingProof = deserOpeningProof(testInputs);
    console.log("Proving...");
    let testProof = await TestCircuit.prove([], [openingProof], testKeypair);
    console.log(testProof);
});
