import path from 'path';
import { Sudoku, SudokuZkApp } from './sudoku.js';
import { generateSudoku, solveSudoku } from './sudoku-lib.js';
import { Mina, PrivateKey, NetworkId, fetchAccount, PublicKey } from 'o1js';
import dotenv from 'dotenv';

dotenv.config({ path: '../../.env' });

const TX_MAX_TRIES = 5;
const FEE = 0.1; // in MINA

let feepayerKey = PrivateKey.fromBase58(process.env.FEEPAYER_KEY as string);
let feepayerAddress = feepayerKey.toPublicKey();

let zkAppAddress = PublicKey.fromBase58("B62qmKCv2HaPwVRHBKrDFGUpjSh3PPY9VqSa6ZweGAmj9hBQL4pfewn");

// define network (devnet)
const Network = Mina.Network({
  networkId: "testnet" as NetworkId,
  mina: "https://api.minascan.io/node/devnet/v1/graphql",
});
const fee = Number(FEE) * 1e9; // in nanomina (1 billion = 1.0 mina)
Mina.setActiveInstance(Network);

// define zkapp and create sudoku to upload
const zkApp = new SudokuZkApp(zkAppAddress);
await fetchAccount({ publicKey: zkAppAddress });
console.log('Is the sudoku solved?', zkApp.isSolved.get().toBoolean());

const sudoku = generateSudoku(0.5);

console.log('Compiling Sudoku');
await SudokuZkApp.compile();

console.log("Sending update transaction");
await trySendTx(
  { sender: feepayerAddress, fee },
  async () => {
    await zkApp.update(Sudoku.from(sudoku));
  }
);

let solution = solveSudoku(sudoku);
if (solution === undefined) throw Error('cannot happen');

// submit the solution
console.log("Sending submit transaction and waiting until it's included in a block");
await trySendTx({ sender: feepayerAddress, fee }, async () => {
  await zkApp.submitSolution(Sudoku.from(sudoku), Sudoku.from(solution!));
});

console.log('Is the sudoku solved?', zkApp.isSolved.get().toBoolean());

async function trySendTx(sender: Mina.FeePayerSpec, f: () => Promise<void>) {
  for (let i = 1; i <= TX_MAX_TRIES; i++) {
    try {
      console.log("Define new transaction");
      const tx = await Mina.transaction(sender, f);

      console.log("Proving transaction");
      await tx.prove();

      console.log('Signing and sending transaction');
      let pendingTx = await tx.sign([feepayerKey]).send();

      if (pendingTx.status === 'pending') {
        console.log(
          `Success! transaction ${pendingTx.hash} sent\n` +
          "Waiting for transaction to be included in a block"
        );
        await pendingTx.wait();
        return;
      }
    } catch (err) {
      console.log(`Failed attempt ${i}/${TX_MAX_TRIES}, will try again`);
      console.log(err);
      continue;
    }
  }

  console.log("Failed all attempts, terminating.");
  process.exit(1);
}
