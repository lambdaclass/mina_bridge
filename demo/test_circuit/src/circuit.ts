import { circuitMain, Circuit, Group, Scalar, public_, Field } from 'o1js';

/** A circuit for testing the demo */
export class TestCircuit extends Circuit {
  @circuitMain
  static main(@public_ input: Scalar) {
    let g = Group.generator;
    g.scale(input);

    // Asserts input == 1;
    g.assertEquals(g);
  }
}
