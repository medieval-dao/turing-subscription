const networkName = hre.network.name

const {ethers} = require('hardhat');


module.exports = async ({
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
  }) => {

    const {deploy} = deployments;
    let accounts = await ethers.getSigners();
    let deployer = accounts[0];
    console.log("=============================");
    console.log("deployer: ", deployer.address);
    console.log("=============================");

    let turingCredit;
    if(networkName == "bobaRinkeby"){
      turingCredit = "0x208c3CE906cd85362bd29467819d3AcbE5FC1614";
    } else if (networkName == "boba") {
      turingCredit = "0xF8D2f1b0292C0Eeef80D8F47661A9DaCDB4b23bf";
    }
  
    // the following will only deploy "GenericMetaTxProcessor" if the contract was never deployed or if the code changed since last deployment
    let turingSubscriptionManager = await deploy('TuringSubscriptionManager', {
      from: deployer.address,
      //gasLimit: 4000000,
      args: [
        turingCredit
      ],
    });
    console.log("turingSubscriptionManager deployed: ", turingSubscriptionManager.address);
  };