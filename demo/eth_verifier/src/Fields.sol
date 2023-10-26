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

    function square(FE self) public pure returns (FE res) {
        res = mul(self, self);
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

    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/
    function pow(FE self, uint exponent) public pure returns (FE result) {
        if (exponent == 0) {
            return FE.wrap(1);
        } else if (exponent == 1) {
            return self;
        } else {
            result = self;

            while (exponent & 1 == 0) {
                result = square(result);
                exponent = exponent >> 1;
            }

            if (exponent == 0) {
                return result;
            } else {
                FE base = result;
                exponent = exponent >> 1;

                while (exponent != 0) {
                    base = square(base);
                    if (exponent & 1 == 1) {
                        result = mul(result, base);
                    }
                    exponent = exponent >> 1;
                }
            }
        }
    }

    /// @notice returns a primitive root of unity of order $2^{order}$.
    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/
    function get_primitive_root_of_unity(
        uint order
    ) public pure returns (FE) {
        FE two_adic_primitive_root_of_unity =
            FieldElement::new();
        if (order == 0) {
            return Ok(FieldElement::one());
        }
        if (order > F::TWO_ADICITY) {
            return Err(FieldError::RootOfUnityError(order));
        }
        let log_power = F::TWO_ADICITY - order;
        let root = (0..log_power).fold(two_adic_primitive_root_of_unity, |acc, _| acc.square());
        Ok(root)
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
