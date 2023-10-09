import { ArgumentType, ArgumentTypeID, GateType } from "./circuits/gate"
import { Scalar } from "o1js"

/**
 * This type can be used to create a mapping between powers of alpha and constraint types.
 * See `default()` to create one (not implemented yet),
 * and `register()` to register a new mapping (not implemented yet).
 * Once you know the alpha value, you can convert this type to a `Alphas`.
*/
export class Alphas {
    /**
     * The next power of alpha to use.
     * The end result will be [1, alpha^(next_power - 1)]
     */
    next_power: number
    /** The mapping between constraint types and powers of alpha */
    mapping: Map<ArgumentTypeID, [number, number]>
    /**
     * The powers of alpha: 1, alpha, alpha^2, ..
     * If not undefined, you can't register new contraints.
    */
    alphas?: Scalar[]

    constructor(
        next_power: number,
        mapping: Map<ArgumentTypeID, [number, number]>,
        alphas?: Scalar[]
    ) {
        this.next_power = next_power;
        this.mapping = mapping,
        this.alphas = alphas;
    }

    /**
     * Instantiates the ranges with an actual field element `alpha`.
     * Once you call this function, you cannot register new constraints.
     */
    instantiate(alpha: Scalar) {
        let last_power = Scalar.from(1);
        let alphas = Array<Scalar>();
        alphas.push(last_power);

        for (let _ = 1; _ < this.next_power; _++) {
            last_power = last_power.mul(alpha);
            alphas.push(last_power);
        }
        this.alphas = alphas;
    }

    /**
     * Retrieves the powers of alpha, upperbounded by `num`
     */
    getAlphas(ty: ArgumentType, num: number) {
        if (ty.kind === "gate") {
            ty.type = GateType.Zero;
        }

        const range = this.mapping.get(ArgumentType.id(ty))!;
        if (num > range[1]) {
            // FIXME: panic! asked for num alphas but there aren't as many.
        }

        return this.alphas!.slice(range[0], range[0] + num);
        // INFO: in kimchi this returns a "MustConsumeIterator", which warns you if
        // not consumed entirely.
    }
}
