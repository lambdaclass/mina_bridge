import { Field } from 'o1js';
import { circuitMain, Circuit, public_ } from 'o1js';

export class Add extends Circuit {
  @circuitMain
  static main(@public_ operand1: Field, @public_ operand2: Field, @public_ result: Field) {
    operand1.add(operand2).assertEquals(result);
  }
}
