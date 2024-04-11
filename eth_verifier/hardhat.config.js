require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");

import * as tdly from "@tenderly/hardhat-tenderly";
tdly.setup();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.21",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
                details: {
                    yulDetails: {
                        optimizerSteps: "u",
                    },
                },
            },
            viaIR: true,
        }
    },
    networks: {
        tenderly_base_devnet: {
            // your Tenderly DevNet RPC
            url: "https://rpc.vnet.tenderly.co/devnet/sepolia-devnet/6bddda23-12db-45d3-b839-c0c54581ed71",
            chainId: 11155111, // used custom Chain ID as a security measure
        }
    },
    tenderly: {
        username: "lambdaclassinfra" ?? "error",
        project: "kimchi-evm-verifier",

        // Contract visible only in Tenderly.
        // Omitting or setting to `false` makes it visible to the whole world.
        // Alternatively, control verification visibility using
        // an environment variable `TENDERLY_PRIVATE_VERIFICATION`.
        privateVerification: true,
    },
};
