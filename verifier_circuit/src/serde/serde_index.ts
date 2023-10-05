import { Group } from "o1js"
import { PolyComm } from "../poly_commitment/commitment"
import { VerifierIndex } from "../verifier/verifier"

export interface PolyCommJSON {
    unshifted: { x: string, y: string }[]
    shifted: null
}

interface VerifierIndexJSON {
    domain_size: number,
    domain_gen: string,
    public: number,
    max_poly_size: number
    zk_rows: number

    sigma_comm: PolyCommJSON[]
    coefficients_comm: PolyCommJSON[]
    generic_comm: PolyCommJSON

    psm_comm: PolyCommJSON

    complete_add_comm: PolyCommJSON
    mul_comm: PolyCommJSON
    emul_comm: PolyCommJSON
    endomul_scalar_comm: PolyCommJSON

    powers_of_alpha: AlphasJSON
    shift: string[]
    zkpm: PolynomialJSON
    w: string
    endo: string
    linear_constant_term: PolishTokenJSON
}

export function deserGroup(x: string, y: string): Group {
    if (x === "0" && y === "1") {
        return Group.zero
    } else {
        return Group.from(x, y);
    }
}

export function deserPolyComm(json: PolyCommJSON): PolyComm<Group> {
    const unshifted = json.unshifted.map(({ x, y }) => deserGroup(x, y));
    let shifted = undefined;
    if (json.shifted != null) {
        shifted = json.shifted;
    }
    return new PolyComm<Group>(unshifted, shifted);
}

export function deserVerifierIndex(json: VerifierIndexJSON): VerifierIndex {
    const {
        domain_size,
        sigma_comm,
        coefficients_comm,
        generic_comm,
        psm_comm,
        complete_add_comm,
        mul_comm,
        emul_comm,
        endomul_scalar_comm,
    } = json;
    const public_size = json.public;

    return new VerifierIndex(
        domain_size,
        public_size,
        sigma_comm.map(deserPolyComm),
        coefficients_comm.map(deserPolyComm),
        deserPolyComm(generic_comm),
        deserPolyComm(psm_comm),
        deserPolyComm(complete_add_comm),
        deserPolyComm(mul_comm),
        deserPolyComm(emul_comm),
        deserPolyComm(endomul_scalar_comm),
    );
}
