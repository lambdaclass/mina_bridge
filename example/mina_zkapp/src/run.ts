import fs from 'fs/promises';
import { Sudoku, SudokuZkApp } from './sudoku.js';
import { generateSudoku, solveSudoku } from './sudoku-lib.js';
import { Mina, PrivateKey, PublicKey, NetworkId, fetchAccount } from 'o1js';

const deployAlias = "devnet";
const ZKAPP_ADDRESS = "B62qmpq1JBejZYDQrZwASPRM5oLXW346WoXgbApVf5HJZXMWFPWFPuA";
const TX_MAX_TRIES = 5;

// parse config and private key from file
type Config = {
  deployAliases: Record<
    string,
    {
      networkId?: string;
      url: string;
      keyPath: string;
      fee: string;
      feepayerKeyPath: string;
      feepayerAlias: string;
    }
  >;
};
let configJson: Config = JSON.parse(await fs.readFile('config.json', 'utf8'));
let config = configJson.deployAliases[deployAlias];
let feepayerKeysBase58: { privateKey: string; publicKey: string } = JSON.parse(
  await fs.readFile(config.feepayerKeyPath, 'utf8')
);
let feepayerKey = PrivateKey.fromBase58(feepayerKeysBase58.privateKey);
let feepayerAddress = feepayerKey.toPublicKey();
let zkAppAddress = PublicKey.fromBase58(ZKAPP_ADDRESS);

// define network (devnet)
const Network = Mina.Network({
  // We need to default to the testnet networkId if none is specified for this deploy alias in config.json
  // This is to ensure the backward compatibility.
  networkId: config.networkId as NetworkId,
  mina: config.url,
});
const fee = Number(config.fee) * 1e9; // in nanomina (1 billion = 1.0 mina)
Mina.setActiveInstance(Network);

// define zkapp and create sudoku to upload
const zkApp = new SudokuZkApp(zkAppAddress);
const sudoku = generateSudoku(0.5);

console.log('Compiling Sudoku');
await SudokuZkApp.compile();

console.log("Sending update transaction and waiting until it's included in a block");
await trySendTx(
  { sender: feepayerAddress, fee },
  async () => {
    await zkApp.update(Sudoku.from(sudoku));
  }
);

console.log('Is the sudoku solved?', zkApp.isSolved.get().toBoolean());

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
      console.log("Defining transaction");
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
