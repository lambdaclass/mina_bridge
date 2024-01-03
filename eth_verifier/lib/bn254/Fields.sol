// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/// @notice Implements 256 bit modular arithmetic over the base field of bn254.
library Base {
    type FE is uint256;

    uint256 public constant MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function zero() public pure returns (FE) {
        return FE.wrap(0);
    }

    function one() public pure returns (FE) {
        return FE.wrap(1);
    }

    function from(uint256 n) public pure returns (FE) {
        return FE.wrap(n % MODULUS);
    }

    function from_bytes_be(bytes memory b) public pure returns (FE) {
        uint256 integer = 0;
        for (uint256 i = 0; i < 32; i++) {
            integer <<= 8;
            integer += uint8(b[i]);
        }
        return FE.wrap(integer % MODULUS);
    }

    function add(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function square(FE self) public pure returns (FE res) {
        assembly {
            res := mulmod(self, self, MODULUS) // mulmod has arbitrary precision
        }
    }

    function inv(FE self) public view returns (FE) {
        require(FE.unwrap(self) != 0, "tried to get inverse of 0");
        (uint256 gcd, uint256 inverse) = Aux.xgcd(FE.unwrap(self), MODULUS);
        require(gcd == 1, "gcd not 1");

        return FE.wrap(inverse);
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
    function pow(FE self, uint256 exponent) public pure returns (FE result) {
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
}

import {console} from "forge-std/console.sol";

/// @notice Implements 256 bit modular arithmetic over the scalar field of bn254.

library Scalar {
    type FE is uint256;

    using {add, mul, inv, neg, sub} for FE;

    uint256 public constant MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 public constant TWO_ADIC_PRIMITIVE_ROOT_OF_UNITY =
        19103219067921713944291392827692070036145651957329286315305642004821462161904;
    uint256 public constant TWO_ADICITY = 28;

    function zero() public pure returns (FE) {
        return FE.wrap(0);
    }

    function one() public pure returns (FE) {
        return FE.wrap(1);
    }

    function from(uint256 n) public pure returns (FE) {
        return FE.wrap(n % MODULUS);
    }

    function from_bytes_be(bytes memory b) public pure returns (FE) {
        uint256 integer = 0;
        uint256 count = b.length <= 32 ? b.length : 32;

        for (uint256 i = 0; i < count; i++) {
            integer <<= 8;
            integer += uint8(b[i]);
        }
        integer <<= (32 - count) * 8;
        return FE.wrap(integer % MODULUS);
    }

    function add(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := addmod(self, other, MODULUS) // addmod has arbitrary precision
        }
    }

    function mul(FE self, FE other) public pure returns (FE res) {
        assembly {
            res := mulmod(self, other, MODULUS) // mulmod has arbitrary precision
        }
    }

    function double(FE self) public pure returns (FE res) {
        res = mul(self, FE.wrap(2));
    }

    function square(FE self) public pure returns (FE res) {
        res = mul(self, self);
    }

    function inv(FE self) public pure returns (FE) {
        require(FE.unwrap(self) != 0, "tried to get inverse of 0");
        (uint256 gcd, uint256 inverse) = Aux.xgcd(FE.unwrap(self), MODULUS);
        require(gcd == 1, "gcd not 1");

        return FE.wrap(inverse);
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
    function pow(FE self, uint256 exponent) public pure returns (FE result) {
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

    error RootOfUnityError();

    /// @notice returns a primitive root of unity of order $2^{order}$.
    // Reference: Lambdaworks
    // https://github.com/lambdaclass/lambdaworks/

    function get_primitive_root_of_unity(uint256 order) public view returns (FE root) {
        if (order == 0) {
            return FE.wrap(1);
        }
        if (order > TWO_ADICITY) {
            revert RootOfUnityError();
        }

        uint256 log_power = TWO_ADICITY - order;
        FE root = from(TWO_ADIC_PRIMITIVE_ROOT_OF_UNITY);
        for (uint256 i = 0; i < log_power; i++) {
            root = square(root);
        }

        require(FE.unwrap(pow(root, 1 << order)) == 1, "not a root of unity");
        return root;
    }
}

library Aux {
    /// @notice Extended euclidean algorithm. Returns [gcd, Bezout_a]
    /// @notice so gcd = a*Bezout_a + b*Bezout_b.
    /// @notice source: https://www.extendedeuclideanalgorithm.com/code
    function xgcd(uint256 a, uint256 b) public pure returns (uint256 r0, uint256 s0) {
        r0 = a;
        uint256 r1 = b;
        s0 = 1;
        uint256 s1 = 0;
        uint256 t0 = 0;
        uint256 t1 = 1;

        uint256 n = 0;
        while (r1 != 0) {
            uint256 q = r0 / r1;
            r0 = r0 > q * r1 ? r0 - q * r1 : q * r1 - r0; // abs

            // swap r0, r1
            uint256 temp = r0;
            r0 = r1;
            r1 = temp;

            s0 = s0 + q * s1;

            // swap s0, s1
            temp = s0;
            s0 = s1;
            s1 = temp;

            t0 = t0 + q * t1;

            // swap t0, t1
            temp = t0;
            t0 = t1;
            t1 = temp;

            ++n;
        }

        if (n % 2 != 0) {
            s0 = b - s0;
        } else {
            t0 = a - t0;
        }
    }
}
