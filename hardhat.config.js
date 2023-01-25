require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${process.env.RPC}`,
        // blockNumber: 15618886,
      },
    },
    matic: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.KEY],
    },
  },

  etherscan: {
    apiKey: process.env.SCAN,
  },
};
