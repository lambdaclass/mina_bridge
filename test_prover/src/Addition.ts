import { Field } from 'o1js';

export class Addition {
    // (a + b) * c = d
    static main(a: Field, b: Field, c: Field, d: Field) {
        a.add(b).mul(c).assertEquals(d);
    }
}
