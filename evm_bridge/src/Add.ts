import { circuitMain, Circuit, Field, public_ } from 'o1js';

/**
 * Basic Example
 * See https://docs.minaprotocol.com/zkapps for more info.
 *
 * The Add contract initializes the state variable 'num' to be a Field(1) value by default when deployed.
 * When the 'update' method is called, the Add contract adds Field(2) to its 'num' contract state.
 *
 * This file is safe to delete and replace with your own contract.
 */
export class Add extends Circuit {
  @circuitMain
  static main(@public_ operand1: Field, @public_ operand2: Field, @public_ result: Field) {
    operand1.add(operand2).assertEquals(result);
  }
}
