// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "mina_bridge/contract/src/MinaStateSettlement.sol";
import "mina_bridge/contract/src/MinaAccountValidation.sol";

contract MinaBalance {
    error InvalidAccount();
    error InvalidLedger(bytes32 ledgerHash); // 76f145ea

    /// @notice Mina bridge contract that validates and stores Mina states.
    MinaStateSettlement stateSettlement;
    /// @notice Mina bridge contract that validates accounts
    MinaAccountValidation accountValidation;

    /// @notice Mapping of account hash (keccak256) to balances for Mina accounts
    mapping(bytes32 => uint64) public balances;

    constructor(address _stateSettlementAddr, address _accountValidationAddr) {
        stateSettlement = MinaStateSettlement(_stateSettlementAddr);
        accountValidation = MinaAccountValidation(_accountValidationAddr);
    }

    function getBalance(bytes32 accountHash) external view returns (uint64) {
        return balances[accountHash];
    }

    /// @notice Validates an accounts balance and stores it
    function updateBalance(
        bytes32 proofCommitment,
        bytes32 provingSystemAuxDataCommitment,
        bytes20 proofGeneratorAddr,
        bytes32 batchMerkleRoot,
        bytes memory merkleProof,
        uint256 verificationDataBatchIndex,
        bytes calldata pubInput,
        address batcherPaymentService
    ) external {
        bytes32 ledgerHash = bytes32(pubInput[:32]);
        if (!stateSettlement.isLedgerVerified(ledgerHash)) {
            revert InvalidLedger(ledgerHash);
        }

        MinaAccountValidation.AlignedArgs memory args = MinaAccountValidation
            .AlignedArgs(
                proofCommitment,
                provingSystemAuxDataCommitment,
                proofGeneratorAddr,
                batchMerkleRoot,
                merkleProof,
                verificationDataBatchIndex,
                pubInput,
                batcherPaymentService
            );

        if (!accountValidation.validateAccount(args)) {
            revert InvalidAccount();
        }

        bytes calldata encodedAccount = pubInput[32 + 8:];
        MinaAccountValidation.Account memory account = abi.decode(
            encodedAccount,
            (MinaAccountValidation.Account)
        );

        bytes32 accountHash = keccak256(encodedAccount);
        balances[accountHash] = account.balance;
    }
}
