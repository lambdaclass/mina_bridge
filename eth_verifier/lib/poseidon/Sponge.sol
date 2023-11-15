// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import "./Permutation.sol";

enum SpongeMode {
    Squeezing,
    Absorbing
}

struct BaseSponge {
    Base.FE[3] state;
    SpongeMode mode;
    uint offset;
}

struct ScalarSponge {
    Scalar.FE[3] state;
    SpongeMode mode;
    uint offset;
}

library Sponge {
    using {Base.mul, Base.add} for Base.FE;
    uint public constant RATE = 2;

    function new_base() public pure returns (BaseSponge memory) {
        return
            BaseSponge(
                [Base.zero(), Base.zero(), Base.zero()],
                SpongeMode.Absorbing,
                0
            );
    }

    function absorb(BaseSponge memory self, Base.FE elem) public pure {
        if (self.mode == SpongeMode.Squeezing) {
            self.mode = SpongeMode.Absorbing;
            self.offset = 0;
        } else if (self.offset == RATE) {
            self.state = Poseidon.permutation(self.state);
            self.offset = 0;
        }

        self.state[self.offset] = self.state[self.offset].add(elem);
        self.offset += 1;
    }

    function squeeze(BaseSponge memory self) public pure returns (Base.FE digest){
        if (self.mode == SpongeMode.Absorbing || self.offset == RATE) {
            self.mode = SpongeMode.Squeezing;
            self.state = Poseidon.permutation(self.state);
            self.offset = 0;
        }

        digest = self.state[self.offset];
        self.offset += 1;
    }
}
