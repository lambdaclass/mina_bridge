// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../pasta/Fields.sol";

library PoseidonSponge {
    struct Sponge {
        Pasta.Fp[3] state;
        uint256 offset;
    }
}
