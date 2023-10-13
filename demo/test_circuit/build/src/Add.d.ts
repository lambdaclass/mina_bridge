import { SmartContract, State } from 'o1js';
/**
 * Basic Example
 * See https://docs.minaprotocol.com/zkapps for more info.
 *
 * The Add contract initializes the state variable 'num' to be a Field(1) value by default when deployed.
 * When the 'update' method is called, the Add contract adds Field(2) to its 'num' contract state.
 *
 * This file is safe to delete and replace with your own contract.
 */
export declare class Add extends SmartContract {
    num: State<import("o1js/dist/node/lib/field").Field>;
    init(): void;
    update(): void;
}
