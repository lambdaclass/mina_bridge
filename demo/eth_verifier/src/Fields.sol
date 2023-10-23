// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/// @notice Implements 256 bit modular arithmetic over the base field of bn254.
library Base {
    type FE is uint256;

    uint256 public constant MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function add(
        FE self,
        FE other
    ) public pure returns (FE res) {
        assembly {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(
        FE self,
        FE other
    ) public pure returns (FE res) {
        assembly {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function inv(FE self) public view returns (FE) {
        // TODO:
        return FE.wrap(0);
    }

    function neg(FE self) public pure returns (FE) {
        return FE.wrap(MODULUS - FE.unwrap(self));
    }

    function sub(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }
}

/// @notice Implements 256 bit modular arithmetic over the scalar field of bn254.
library Scalar {
    type FE is uint256;

    using { add, mul, inv, neg, sub } for FE;

    uint256 public constant MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function add(
        FE self,
        FE other
    ) public pure returns (FE res) {
        assembly {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(
        FE self,
        FE other
    ) public pure returns (FE res) {
        assembly {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function inv(FE self) public view returns (FE) {
        // TODO:
        return FE.wrap(0);
    }

    function neg(FE self) public pure returns (FE) {
        return FE.wrap(MODULUS - FE.unwrap(self));
    }

    function sub(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := addmod(self, sub(MODULUS, other), MODULUS)
        }
    }
}
