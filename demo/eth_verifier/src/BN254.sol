// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {BaseField} from "./Fields.sol";

library BN254 {
    type Base is uint256;
    type Scalar is uint256;

    using {BaseField.add as +, BaseField.mul as *} for Base;

    struct G1 {
        uint256 x;
        uint256 y;
    }

    function point_at_inf() public pure returns (G1 memory) {
        return G1(0, 0);
    }

    function in_curve(G1 memory p1) public pure returns (bool) {
        //return p1.y ** 2 == p1.x ** 3 + 3;
        return true; // FIXME: overflows
    }

    function add(G1 memory p1, G1 memory p2) public view returns (G1 memory) {
        if (!in_curve(p1) || !in_curve(p2)) {
            return point_at_inf();
        }

        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;

        (bool success, bytes memory output) = address(0x06).staticcall(
            abi.encode(input)
        );
        if (success) {
            return abi.decode(output, (G1));
        } else {
            return point_at_inf();
        }
    }

    function scale(G1 memory p, uint256 k) public view returns (G1 memory) {
        if (!in_curve(p1) || !in_curve(p2)) {
            return point_at_inf();
        }

        uint256[4] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = k;

        (bool success, bytes memory output) = address(0x07).staticcall(
            abi.encode(input)
        );
        if (success) {
            return abi.decode(output, (G1));
        } else {
            return point_at_inf();
        }
    }
}
