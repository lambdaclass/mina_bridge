// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

uint256 constant COLUMNS = 15;
uint256 constant PERMUTS = 7;

uint256 constant PERMUTATION_CONSTRAINTS = 3;
uint256 constant VARBASEMUL_CONSTRAINTS = 21;

// NewProofEvals bit flag positions
uint256 constant PUBLIC_EVALS_FLAG = 0;
uint256 constant RANGE_CHECK0_SELECTOR_EVAL_FLAG = 1;
uint256 constant RANGE_CHECK1_SELECTOR_EVAL_FLAG = 2;
uint256 constant FOREIGN_FIELD_ADD_SELECTOR_EVAL_FLAG = 3;
uint256 constant FOREIGN_FIELD_MUL_SELECTOR_EVAL_FLAG = 4;
uint256 constant XOR_SELECTOR_EVAL_FLAG = 5;
uint256 constant ROT_SELECTOR_EVAL_FLAG = 6;
uint256 constant LOOKUP_AGGREGATION_EVAL_FLAG = 7;
uint256 constant LOOKUP_TABLE_EVAL_FLAG = 8;
uint256 constant LOOKUP_SORTED_EVAL_FLAG = 9; // these are 5
uint256 constant RUNTIME_LOOKUP_TABLE_EVAL_FLAG = 14;
uint256 constant RUNTIME_LOOKUP_TABLE_SELECTOR_EVAL_FLAG = 15;
uint256 constant XOR_LOOKUP_SELECTOR_EVAL_FLAG = 16;
uint256 constant LOOKUP_GATE_LOOKUP_SELECTOR_EVAL_FLAG = 17;
uint256 constant RANGE_CHECK_LOOKUP_SELECTOR_EVAL_FLAG = 18;
uint256 constant FOREIGN_FIELD_MUL_LOOKUP_SELECTOR_EVAL_FLAG = 19;

// ProofCommitments bit flag positions
uint256 constant LOOKUP_SORTED_COMM_FLAG = 0;
uint256 constant LOOKUP_AGGREG_COMM_FLAG = 1;
uint256 constant LOOKUP_RUNTIME_COMM_FLAG = 2;

// VerifierIndex bit flag positions
uint256 constant RANGE_CHECK0_COMM_FLAG = 0;
uint256 constant RANGE_CHECK1_COMM_FLAG = 1;
uint256 constant FOREIGN_FIELD_ADD_COMM_FLAG = 2;
uint256 constant FOREIGN_FIELD_MUL_COMM_FLAG = 3;
uint256 constant XOR_COMM_FLAG = 4;
uint256 constant ROT_COMM_FLAG = 5;
uint256 constant LOOKUP_VERIFIER_INDEX_FLAG = 6;

// LookupVerifierIndex bit flag positions
uint256 constant XOR_FLAG = 0;
uint256 constant LOOKUP_FLAG = 1;
uint256 constant RANGE_CHECK_FLAG = 2;
uint256 constant FFMUL_FLAG = 3;
uint256 constant TABLE_IDS_FLAG = 4;
uint256 constant RUNTIME_TABLES_SELECTOR_FLAG = 5;
