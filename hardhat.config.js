require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');
require('hardhat-deploy');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    boba: {
      url: "https://mainnet.boba.network",
      accounts: [process.env.DEPLOYER_KEY]
    },
    bobaRinkeby: {
      url: "https://rinkeby.boba.network",
      accounts: [process.env.TEST_DEPLOYER_KEY]
    },
    bobaAvaxTest: {
      url: "https://testnet.avax.boba.network",
      accounts: [process.env.DEPLOYER_KEY]
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }]
  }
};
