// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

library Pasta {
    type Fp is uint256;

    uint256 internal constant MODULUS = 28948022309329048855892746252171976963363056481941560715954676764349967630337;

    function zero() internal pure returns (Fp) {
        return Fp.wrap(0);
    }

    function one() internal pure returns (Fp) {
        return Fp.wrap(1);
    }

    function from(uint256 n) internal pure returns (Fp) {
        return Fp.wrap(n);
    }

    function add(Fp self, Fp other) internal pure returns (Fp res) {
        assembly ("memory-safe") {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(Fp self, Fp other) internal pure returns (Fp res) {
        assembly ("memory-safe") {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function pow(Fp self, uint256 exponent) internal view returns (Fp result) {
        uint256 base = Fp.unwrap(self);
        uint256 o;
        assembly ("memory-safe") {
            // define pointer
            let p := mload(0x40)
            // store data assembly-favouring ways
            mstore(p, 0x20) // Length of Base
            mstore(add(p, 0x20), 0x20) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), base) // Base
            mstore(add(p, 0x80), exponent) // Exponent
            mstore(add(p, 0xa0), MODULUS) // Modulus
            if iszero(staticcall(sub(gas(), 2000), 0x05, p, 0xc0, p, 0x20)) { revert(0, 0) }
            // data
            o := mload(p)
        }
        result = Fp.wrap(o);
    }
}
