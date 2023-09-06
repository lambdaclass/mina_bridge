import { circuitMain, Circuit, public_ } from 'o1js';
import { PastaField } from './PastaField.js';

export class Add extends Circuit {
  @circuitMain
  static main(@public_ operand1: PastaField, @public_ operand2: PastaField, @public_ result: PastaField) {
    operand1.add(operand2).assertEquals(result);
  }
}
