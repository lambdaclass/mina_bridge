export class PolyComm<C> {
    unshifted: C[]
    shifted?: C

    constructor(unshifted: C[], shifted?: C) {
        this.unshifted = unshifted;
        this.shifted = shifted;
    }

    zip<D>(other: PolyComm<D>): PolyComm<[C, D]> {
        let unshifted = this.unshifted.map((u, i) => {
            return [u, other.unshifted[i]];
        });
        let shifted = [this.shifted, other.shifted];
        return new PolyComm<[C, D]>(unshifted, shifted);
    }
}

export class BlindedCommitment<C, S> {
    commitment: PolyComm<C>
    blinders: PolyComm<S>
}
