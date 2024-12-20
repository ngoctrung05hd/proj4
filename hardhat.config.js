require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-ethers")
module.exports = {
  solidity: "0.8.17",
  networks: {
    bscTestnet: {
      url: process.env.API_URL,
      accounts: [process.env.PRIVATE_KEY],
    }
  }
};
