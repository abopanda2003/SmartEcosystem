const path = require('path')
const Utils = require('../Utils');
const { ethers, getNamedAccounts, getChainId, deployments } = require("hardhat");
const { deploy } = deployments;

// const { deploy1820 } = require('deploy-eip-1820');
const chalk = require('chalk');
const fs = require('fs');

const uniswapRouterABI = require("../artifacts/contracts/interfaces/IUniswapRouter.sol/IUniswapV2Router02.json").abi;
const bep20ABI = require("../artifacts/contracts/libs/IBEP20.sol/IBEP20.json").abi;

const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay * 1000));


function dim() {
  if (!process.env.HIDE_DEPLOY_LOG) {
    console.log(chalk.dim.call(chalk, ...arguments));
  }
}

function cyan() {
  if (!process.env.HIDE_DEPLOY_LOG) {
    console.log(chalk.cyan.call(chalk, ...arguments));
  }
}

function yellow() {
  if (!process.env.HIDE_DEPLOY_LOG) {
    console.log(chalk.yellow.call(chalk, ...arguments));
  }
}

function green() {
  if (!process.env.HIDE_DEPLOY_LOG) {
    console.log(chalk.green.call(chalk, ...arguments));
  }
}

function displayResult(name, result) {
  if (!result.newlyDeployed) {
    yellow(`Re-used existing ${name} at ${result.address}`);
  } else {
    green(`${name} deployed at ${result.address}`);
  }
}

const chainName = (chainId) => {
  switch (chainId) {
    case 1:
      return 'Mainnet';
    case 3:
      return 'Ropsten';
    case 4:
      return 'Rinkeby';
    case 5:
      return 'Goerli';
    case 42:
      return 'Kovan';
    case 56:
      return 'Binance Smart Chain';
    case 77:
      return 'POA Sokol';
    case 97:
      return 'Binance Smart Chain (testnet)';
    case 99:
      return 'POA';
    case 100:
      return 'xDai';
    case 137:
      return 'Matic';
    case 1337:
        return 'HardhatEVM';
    case 31337:
      return 'HardhatEVM';
    case 80001:
      return 'Matic (Mumbai)';
    default:
      return 'Unknown';
  }
};

async function main() {

    const { getContractFactory, getSigners } = ethers;
    // let { anotherUser } = await getNamedAccounts();
    let [owner, userWallet, anotherUser] = await getSigners();

    const chainId = parseInt(await getChainId(), 10);
    const upgrades = hre.upgrades;

    dim('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    dim('Adamant NFT Contracts - Deploy Script');
    dim('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    dim(`Network: ${chainName(chainId)}`);

    // if(chainId !== 97 && chainId !== 1337){
    //     console.log(">>>>>>>>>>> unsupported blockchain >>>>>>>>>>>>>>");
    //     return;
    // }

    console.log("owner:", owner.address);
    console.log("user:", userWallet.address);
    console.log("another user:", anotherUser.address);
    console.log("chain id:", chainId);

    cyan(`\nDeploying Adamant Token...`);
    let deployedAdamant = await deploy('Adamant', {
      from: owner.address,
      skipIfAlreadyDeployed: true
    });
    displayResult('Adamant Token Contract', deployedAdamant);

    cyan(`\nDeploying NFT Market...`);
    let deployedMarket = await deploy('NFTMarket', {
      from: owner.address,
      skipIfAlreadyDeployed: true
    });
    displayResult('NFT Market Contract', deployedMarket);
    
    cyan(`\nDeploying NFT Contract...`);
    let deployedNFT = await deploy('NFT', {
      from: owner.address,
      args:[deployedMarket.address],
      skipIfAlreadyDeployed: true
    });
    displayResult('NFT Contract', deployedNFT);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
