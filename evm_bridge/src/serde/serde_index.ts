import { Group, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment"
import { VerifierIndex } from "../verifier/verifier"

type PolyCommJSON = {
    unshifted: { x: string, y: string }[]
    shifted: null
}

interface VerifierIndexJSON {
    domain_size: number,
    public: number,

    sigma_comm: PolyCommJSON[]
    coefficients_comm: PolyCommJSON[]
    generic_comm: PolyCommJSON

    psm_comm: PolyCommJSON

    complete_add_comm: PolyCommJSON
    mul_comm: PolyCommJSON
    emul_comm: PolyCommJSON
    endomul_scalar_comm: PolyCommJSON
}

export function deserScalar(str: string): Scalar {
    if (!str.startsWith("0x")) str = "0x" + str;
    return Scalar.from(str);
}

export function deserPolyComm(json: PolyCommJSON): PolyComm<Group> {
    const unshifted = json.unshifted.map(({ x, y }) => Group.from(x, y));
    return new PolyComm(unshifted, json.shifted);
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
