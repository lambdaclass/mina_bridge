/**
 * This file specifies how to run the `SudokuZkApp` smart contract locally using the `Mina.LocalBlockchain()` method.
 * The `Mina.LocalBlockchain()` method specifies a ledger of accounts and contains logic for updating the ledger.
 *
 * Please note that this deployment is local and does not deploy to a live network.
 * If you wish to deploy to a live network, please use the zkapp-cli to deploy.
 *
 * To run locally:
 * Build the project: `$ npm run build`
 * Run with node:     `$ node build/src/run.js`.
 */
import fs from 'fs/promises';
import { Sudoku, SudokuZkApp } from './sudoku.js';
import { cloneSudoku, generateSudoku, solveSudoku } from './sudoku-lib.js';
import { AccountUpdate, Mina, PrivateKey, NetworkId } from 'o1js';

const deployAlias = "devnet";

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
let zkAppKeysBase58: { privateKey: string; publicKey: string } = JSON.parse(
  await fs.readFile(config.keyPath, 'utf8')
);
let feepayerKey = PrivateKey.fromBase58(feepayerKeysBase58.privateKey);
let zkAppKey = PrivateKey.fromBase58(zkAppKeysBase58.privateKey);
let feepayerAddress = feepayerKey.toPublicKey();
let zkAppAddress = zkAppKey.toPublicKey();

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

console.log('compiling Sudoku...');
await SudokuZkApp.compile();

console.log('updating sudoku to solve');
try {
  // call update() and send transaction
  console.log('build transaction and create proof...');
  let tx = await Mina.transaction(
    { sender: feepayerAddress, fee },
    async () => {
      await zkApp.update(Sudoku.from(sudoku));
    }
  );
  await tx.prove();

  console.log('send transaction...');
  const sentTx = await tx.sign([feepayerKey]).send();
  if (sentTx.status === 'pending') {
    console.log(
      '\nSuccess! Update transaction sent.\n' +
      '\nYour smart contract state will be updated' +
      '\nas soon as the transaction is included in a block:' +
      `\n${getTxnUrl(config.url, sentTx.hash)}`
    );
  }
} catch (err) {
  console.log(err);
}

console.log('Is the sudoku solved? (should be false)', zkApp.isSolved.get().toBoolean());

let solution = solveSudoku(sudoku);
if (solution === undefined) throw Error('cannot happen');

// submit the solution
console.log('Submitting solution...');
let tx = await Mina.transaction({ sender: feepayerAddress, fee }, async () => {
  await zkApp.submitSolution(Sudoku.from(sudoku), Sudoku.from(solution!));
});
await tx.prove();
await tx.sign([feepayerKey]).send();

console.log('Is the sudoku solved?', zkApp.isSolved.get().toBoolean());

function getTxnUrl(graphQlUrl: string, txnHash: string | undefined) {
  const hostName = new URL(graphQlUrl).hostname;
  const txnBroadcastServiceName = hostName
    .split('.')
    .filter((item) => item === 'minascan')?.[0];
  const networkName = graphQlUrl
    .split('/')
    .filter((item) => item === 'mainnet' || item === 'devnet')?.[0];
  if (txnBroadcastServiceName && networkName) {
    return `https://minascan.io/${networkName}/tx/${txnHash}?type=zk-tx`;
  }
  return `Transaction hash: ${txnHash}`;
}
