// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

uint constant COLUMNS = 15;
uint constant PERMUTS = 7;

uint constant PERMUTATION_CONSTRAINTS = 3;
uint constant VARBASEMUL_CONSTRAINTS = 21;

// ProofEvals bit flag positions
uint constant PUBLIC_EVALS_FLAG = 0;
uint constant RANGE_CHECK0_SELECTOR_EVAL_FLAG = 1;
uint constant RANGE_CHECK1_SELECTOR_EVAL_FLAG = 2;
uint constant FOREIGN_FIELD_ADD_SELECTOR_EVAL_FLAG = 3;
uint constant FOREIGN_FIELD_MUL_SELECTOR_EVAL_FLAG = 4;
uint constant XOR_SELECTOR_EVAL_FLAG = 5;
uint constant ROT_SELECTOR_EVAL_FLAG = 6;
uint constant LOOKUP_AGGREGATION_EVAL_FLAG = 7;
uint constant LOOKUP_TABLE_EVAL_FLAG = 8;
uint constant LOOKUP_SORTED_EVAL_FLAG = 9; // these are 5
uint constant RUNTIME_LOOKUP_TABLE_EVAL_FLAG = 14;
uint constant RUNTIME_LOOKUP_TABLE_SELECTOR_EVAL_FLAG = 15;
uint constant XOR_LOOKUP_SELECTOR_EVAL_FLAG = 16;
uint constant LOOKUP_GATE_LOOKUP_SELECTOR_EVAL_FLAG = 17;
uint constant RANGE_CHECK_LOOKUP_SELECTOR_EVAL_FLAG = 18;
uint constant FOREIGN_FIELD_MUL_LOOKUP_SELECTOR_EVAL_FLAG = 19;

// ProofCommitments bit flag positions
uint constant LOOKUP_SORTED_COMM_FLAG = 0;
uint constant LOOKUP_AGGREG_COMM_FLAG = 1;
uint constant LOOKUP_RUNTIME_COMM_FLAG = 2;
