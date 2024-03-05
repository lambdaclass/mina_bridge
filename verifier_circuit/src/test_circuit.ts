import { Circuit, CircuitBn254, Field, FieldBn254, circuitMain, circuitMainBn254, public_ } from 'o1js';

export class TestCircuit extends Circuit {
    @circuitMain
    static main(@public_ a: Field) {
        a.assertEquals(Field.from(5));
    }
}

export class TestCircuitBn254 extends CircuitBn254 {
    @circuitMainBn254
    static main(@public_ a: FieldBn254) {
        a.assertEquals(FieldBn254.from(5));
    }
}
