import { Bool, Field, Provable } from "o1js";
import { ForeignField } from "./foreign_field.js";
import { ForeignScalar } from "./foreign_scalar.js";

export class ForeignGroup {
    x: ForeignField;
    y: ForeignField;

    constructor(x: ForeignField, y: ForeignField) {
        this.x = x;
        this.y = y;
    }

    static zero() {
        return new ForeignGroup(ForeignField.from(0), ForeignField.from(0));
    }

    isZero() {
        // only the zero element can have x = 0, there are no other (valid) group elements with x = 0
        return this.x.equals(ForeignField.from(0));
    }

    assertEquals(g: ForeignGroup, message?: string) {
        let { x: x1, y: y1 } = this;
        let { x: x2, y: y2 } = g;

        x1.assertEquals(x2, message);
        y1.assertEquals(y2, message);
    }

    equals(g: ForeignGroup) {
        let { x: x1, y: y1 } = this;
        let { x: x2, y: y2 } = g;

        let x_are_equal = x1.equals(x2);
        let y_are_equal = y1.equals(y2);

        return x_are_equal.and(y_are_equal);
    }

    add(g: ForeignGroup) {
        // TODO: Make provable and use foreign EC constraints

        const { x: x1, y: y1 } = this;
        const { x: x2, y: y2 } = g;

        let inf = Provable.witness(Bool, () =>
            x1.equals(x2).and(y1.equals(y2).not())
        );

        let s = Provable.witness(ForeignField, () => {
            if (x1.equals(x2).toBoolean()) {
                let x1_squared = x1.mul(x1);
                return x1_squared.add(x1_squared).add(x1_squared).mul(y1.add(y1).inv());
            } else return y2.sub(y1).mul(x2.sub(x1).inv());
        });

        let x3 = Provable.witness(ForeignField, () => {
            return s.mul(s).sub(x1.add(x2));
        });

        let y3 = Provable.witness(ForeignField, () => {
            return s.mul(x1.sub(x3)).sub(y1);
        });

        // similarly to the constant implementation, we check if either operand is zero
        // and the implementation above (original OCaml implementation) returns something wild -> g + 0 != g where it should be g + 0 = g
        let gIsZero = g.isZero();
        let thisIsZero = this.isZero();

        let bothZero = gIsZero.and(thisIsZero);

        let onlyGisZero = gIsZero.and(thisIsZero.not());
        let onlyThisIsZero = thisIsZero.and(gIsZero.not());

        let isNegation = inf;

        let isNewElement = bothZero
            .not()
            .and(isNegation.not())
            .and(onlyThisIsZero.not())
            .and(onlyGisZero.not());

        const zero_g = ForeignGroup.zero();

        return Provable.switch(
            [bothZero, onlyGisZero, onlyThisIsZero, isNegation, isNewElement],
            ForeignGroup,
            [zero_g, this, g, zero_g, new ForeignGroup(x3, y3)]
        );
    }

    scale(s: ForeignScalar) {
        let coefficient = s.toBits();
        let current = new ForeignGroup(this.x, this.y);
        let result = ForeignGroup.zero();

        while (coefficient.length > 0) {
            result = Provable.if(coefficient[coefficient.length - 1], ForeignGroup, result.add(current), result);
            current = current.add(current);
            coefficient.pop();
        }

        return result;
    }

    static sizeInFields() {
        return ForeignField.sizeInFields() * 2;
    }

    static fromFields(fields: Field[]) {
        let x = fields.slice(0, 3);
        let y = fields.slice(3);

        return new ForeignGroup(ForeignField.fromFields(x), ForeignField.fromFields(y));
    }

    toFields() {
        return [...this.x.toFields(), ...this.y.toFields()];
    }

    static toFields(g: ForeignGroup) {
        return g.toFields();
    }

    static toAuxiliary() {
        return [];
    }

    static check(g: ForeignGroup) {
        try {
            const a = 0n;
            const b = 5n;
            const { x, y } = g;

            let x2 = x.mul(x);
            let x3 = x2.mul(x);
            let ax = x.mul(a); // this will obviously be 0, but just for the sake of correctness

            // we also check the zero element (0, 0) here
            let isZero = x.equals(0).and(y.equals(0));

            isZero.or(x3.add(ax).add(b).equals(y.mul(y))).assertTrue();
        } catch (error) {
            if (!(error instanceof Error)) return error;
            throw `${`Element (x: ${g.x}, y: ${g.y}) is not an element of the group.`}\n${error.message}`;
        }
    }
}
