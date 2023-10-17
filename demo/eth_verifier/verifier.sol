// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

library Kimchi {
    struct Proof {
        uint data;
    }
}

contract KimchiVerifier {
    function verify() public view returns (bool) {
        return true;
    }
}
