
library Oracles {
    function fiat_shamir() public view {
        // We'll skip the use of a sponge and generate challenges from pseudo-random numbers
        uint256 chal = challenge();
    }

    /// @notice creates a challenge from hashing the current block timestamp.
    /// @notice this function is only going to be used for the demo and never in
    /// @notice a serious environment. DO NOT use this in any other case.
    function challenge() internal view returns (uint256) {
        keccak256(abi.encode(block.timestamp));
    }
}
