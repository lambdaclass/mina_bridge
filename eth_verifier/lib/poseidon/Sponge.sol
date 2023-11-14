// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

enum SpongeMode {
    Squeezing,
    Absorbing
}

struct BaseSponge {
    Base.FE[3] state; // rate = 2
    SpongeMode mode;
    uint offset;
}

struct ScalarSponge {
    Scalar.FE[3] state; // rate = 2
    SpongeMode mode;
    uint offset;
}

library Sponge {
    uint public constant RATE = 2;

    function new_base() public pure returns (BaseSponge memory) {
        return
            BaseSponge(
                [Base.zero(), Base.zero(), Base.zero()],
                SpongeMode.Absorbing,
                0
            );
    }
}
