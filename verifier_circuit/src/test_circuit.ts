import { Circuit, CircuitBn254, Field, FieldBn254, Provable, circuitMain, circuitMainBn254, public_ } from 'o1js';

export class TestCircuit extends CircuitBn254 {
    @circuitMainBn254
    static main(@public_ a: FieldBn254) {
        a.assertEquals(FieldBn254.from(5));
    }
}
