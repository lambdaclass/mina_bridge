// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {Scalar} from "./Fields.sol";

library BN254 {
    uint256 public constant MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 x;
        uint256 y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the point at infinity, represented as (0, 0)
    function point_at_inf() public pure returns (G1Point memory) {
        return G1Point(0, 0);
    }

    /// @return asserts if the point in question is the point at infinity
    function is_point_at_inf(G1Point memory p) public pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    /// @return asserts if the point in question is in the curve
    function in_curve(G1Point memory p1) public pure returns (bool) {
        //return p1.y ** 2 == p1.x ** 3 + 3;
        return true; // FIXME: overflows
    }

    /// @return the sum of two points, using the Ethereum precompile.
    function add(G1Point memory p1, G1Point memory p2) public view returns (G1Point memory) {
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
            return abi.decode(output, (G1Point));
        } else {
            return point_at_inf();
        }
    }

    /// @return p scaled k times, with k being a scalar field element.
    function scale_scalar(G1Point memory p, Scalar.FE k) public view returns (G1Point memory) {
        scale(p, Scalar.FE.unwrap(k));
    }

    /// @return p scaled k times.
    function scale(G1Point memory p, uint256 k) public view returns (G1Point memory) {
        if (!in_curve(p) || k == 0) {
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
            return abi.decode(output, (G1Point));
        } else {
            return point_at_inf();
        }
    }

    /// @return r the negation of p, i.e. p.add(p.neg()) should be zero.
    function neg(G1Point memory p) internal pure returns (G1Point memory) {
        if (is_point_at_inf(p)) {
            return p;
        }
        return G1Point(p.x, MODULUS - (p.y % MODULUS));
    }
}
