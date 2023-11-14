// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

/// configured specifically for Kimchi
library Poseidon {
    using {Base.inv, Base.mul, Base.add} for Base.FE;

    function sbox(Base.FE elem) public pure returns (Base.FE) {
        return Base.pow(elem, 7);
    }

    function apply_mds(
        Base.FE[3] memory state
    ) public view returns (Base.FE[3] memory n) {
        Base.FE[3][3] memory mds = [
            [Base.from(3).inv(), Base.from(4).inv(), Base.from(5).inv()],
            [Base.from(4).inv(), Base.from(5).inv(), Base.from(6).inv()],
            [Base.from(5).inv(), Base.from(6).inv(), Base.from(7).inv()]
        ]; // calculated as a cauchy matrix of [0, 1, 2] and [3, 4, 5].

        n[0] = state[0].mul(mds[0][0]).add(state[1].mul(mds[0][1])).add(
            state[2].mul(mds[0][2])
        );
        n[1] = state[0].mul(mds[1][0]).add(state[1].mul(mds[1][1])).add(
            state[2].mul(mds[1][2])
        );
        n[2] = state[0].mul(mds[2][0]).add(state[1].mul(mds[2][1])).add(
            state[2].mul(mds[2][2])
        );
    }

    function apply_round(
        uint round,
        Base.FE[3] memory state
    ) public view returns (Base.FE[3] memory new_state) {
        state[0] = sbox(state[0]);
        state[1] = sbox(state[1]);
        state[2] = sbox(state[2]);

        state = apply_mds(state)

        state[0] = state[0].add(round_constants[round][0]);
        state[1] = state[1].add(round_constants[round][1]);
        state[2] = state[2].add(round_constants[round][2]);
    }
}
