const path = require('path')
const Utils = require('../Utils');
const { ethers, getNamedAccounts, getChainId, deployments } = require("hardhat");
const { deploy } = deployments;
const { expect } = require('chai');

// const { deploy1820 } = require('deploy-eip-1820');
const chalk = require('chalk');
const fs = require('fs');

const uniswapRouterABI = require("../artifacts/contracts/interfaces/IUniswapRouter.sol/IUniswapV2Router02.json").abi;
const uniswapPairABI = require("../artifacts/contracts/libs/dexfactory.sol/IPancakeSwapPair.json").abi;

const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay * 1000));

let owner, userWallet, anotherUser, sponsor1, sponsor2;
let smtContract, SmartLadderContract;

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

const displayWalletBalances = async (tokenIns, bOwner, bAnother, bUser, bSponsor1, bSponsor2) => {
  if(bOwner){
    let balance = await tokenIns.balanceOf(owner.address);
    console.log("owner balance:",
                ethers.utils.formatEther(balance.toString()));  
  }

  if(bAnother){
    let balance = await tokenIns.balanceOf(anotherUser.address);
    console.log("another user balance:",
                ethers.utils.formatEther(balance.toString()));  
  }

  if(bUser){
    let balance = await tokenIns.balanceOf(userWallet.address);
    console.log("user balance:",
                ethers.utils.formatEther(balance.toString()));  
  }

  if(bSponsor1){
    let balance = await tokenIns.balanceOf(sponsor1.address);
    console.log("sponsor1 balance:",
                ethers.utils.formatEther(balance.toString()));  
  }

  if(bSponsor2){
    let balance = await tokenIns.balanceOf(sponsor2.address);
    console.log("sponsor2 balance:",
                ethers.utils.formatEther(balance.toString()));  
  }
};

const displayLiquidityPoolBalance = async(comment, poolInstance) => {
  let reservesPair = await poolInstance.getReserves();
  console.log(comment);
  console.log("token0:", ethers.utils.formatEther(reservesPair.reserve0));
  console.log("token1:", ethers.utils.formatEther(reservesPair.reserve1));
}

const displayUserInfo = async(farmContract, wallet) => {
  let info = await farmContract.userInfoOf(wallet.address);
  cyan("-------------------------------------------");
  console.log("balance of wallet:", ethers.utils.formatEther(info.balance));
  console.log("rewards of wallet:", info.rewards.toString());
  console.log("reward per token paid of wallet:", info.rewardPerTokenPaid.toString());
  console.log("last updated time of wallet:", info.balance.toString());
}

const addLiquidityToPools = async(
                tokenA, tokenB,
                routerInstance, walletIns,
                smtAmount1, bnbAmount, 
                smtAmount2, busdAmount
) => {
  ///////////////////  SMT-BNB Add Liquidity /////////////////////
  tx = await tokenA.connect(walletIns).approve(
    routerInstance.address,
    ethers.utils.parseUnits(Number(smtAmount1+100).toString(),18)
  );
  await tx.wait();

  console.log("approve tx: ", tx.hash);

  tx = await routerInstance.connect(walletIns).addLiquidityETH(
    tokenA.address,
    ethers.utils.parseUnits(Number(smtAmount1).toString(), 18),
    0,
    0,
    walletIns.address,
    "111111111111111111111",
    {value : ethers.utils.parseUnits(Number(bnbAmount).toString(), 18)}
  );
  await tx.wait();
  console.log("SMT-BNB add liquidity tx: ", tx.hash);
    
  ///////////////////  SMT-BUSD Add Liquidity /////////////////////

  tx = await tokenA.connect(walletIns).approve(
      routerInstance.address,
      ethers.utils.parseUnits(Number(smtAmount2+100).toString(), 18)
  );
  await tx.wait();

  tx = await tokenB.connect(walletIns).approve(
      routerInstance.address,        
      ethers.utils.parseUnits(Number(busdAmount+100).toString(), 18)
  );
  await tx.wait();  
    
  tx = await routerInstance.connect(walletIns).addLiquidity(
      tokenA.address,
      tokenB.address,
      ethers.utils.parseUnits(Number(smtAmount2).toString(), 18),
      ethers.utils.parseUnits(Number(busdAmount).toString(), 18),
      0,
      0,
      walletIns.address,
      "111111111111111111111"
  );
  await tx.wait();
  console.log("SMT-BUSD add liquidity tx: ", tx.hash);
}

const displayAllLicense = async(smartArmyContract) => {
  cyan("============= Created Licenses =============");
  let count = await smartArmyContract.countOfLicenses();
  cyan(`total license count: ${count}`);
  let defaultLics = await smartArmyContract.fetchAllLicenses();
  for(let i=0; i<defaultLics.length; i++) {
    console.log("************ index", i, " **************");
    console.log("level:", defaultLics[i].level.toString());
    console.log("name:", defaultLics[i].name.toString());
    console.log("price:", ethers.utils.formatEther(defaultLics[i].price.toString()));
    console.log("ladderLevel:", defaultLics[i].ladderLevel.toString());
    console.log("duration:", defaultLics[i].duration.toString());
  }
}

const buyLicense = async(smtTokenIns, smartArmyContract, wallet, sponsor) => {
  cyan("============= Register Licenses =============");
  let userBalance = await smtTokenIns.balanceOf(wallet.address);
  userBalance = ethers.utils.formatEther(userBalance);

  const license = await smartArmyContract.licenseTypeOf(1);
  let price = ethers.utils.formatEther(license.price);
  
  if(userBalance < price) {        
    console.log("charge SMT token to your wallet!!!!");
    return;
  }

  let licId = await smartArmyContract.licenseIdOf(wallet.address);
  if(licId == 0) {
    let tx = await smartArmyContract.connect(wallet).registerLicense(
      1, sponsor.address, "Arsenii", "https://t.me.Ivan", "https://ipfs/2314341dwer242"
    );
    await tx.wait();
    console.log("License register transaction:", tx.hash);  
  } else {
    cyan(`Current user with license ${licId} was registered`);
    displayLicenseOf(smartArmyContract, wallet.address);  
  }

  let balance = await smtTokenIns.balanceOf(wallet.address);
  expect(parseInt(ethers.utils.formatEther(balance))).to.greaterThan(0);

  let tx = await smtTokenIns.connect(wallet).approve(
    smartArmyContract.address,
    ethers.utils.parseUnits(Number(price).toString(), 18)
  );
  await tx.wait();
  console.log("Activation approved transaction: ", tx.hash);

  tx = await smartArmyContract.connect(wallet).activateLicense();
  await tx.wait();
  console.log("License Activate transaction: ", tx.hash);
}

const displayLicenseOf = async(smartArmyContract, userAddress) => {
  let userLic = await smartArmyContract.licenseOf(userAddress);
  console.log("----------- user license ---------------");
  console.log("owner: ", userLic.owner);
  console.log("level: ", userLic.level.toString());
  console.log("start at: ", userLic.startAt.toString());
  console.log("active at: ", userLic.activeAt.toString());
  console.log("expire at: ", userLic.expireAt.toString());
  console.log("lp locked: ", ethers.utils.formatEther(userLic.lpLocked.toString()));
  console.log("status: ", userLic.status);
}

const displayTitle = (strTitle) => {
  cyan("*********************************");
  cyan(`${strTitle}`);
  cyan("*********************************");
}

async function main() {

    const { getNamedAccounts } = hre;
    const { getContractFactory, getSigners } = ethers;

    let {
        NA_Router,
        NA_SmartComp,
        NA_SmartBridge,
        NA_GoldenTreePool,
        NA_NobilityAch,
        NA_OtherAch,
        NA_SmartArmy,
        NA_SmartFarm,
        NA_SmartLadder,
        NA_Busd,
        NA_SMT,
        NA_SMTC,
        NA_SMTCC,
        NA_SMTCD
    } = await getNamedAccounts();

    console.log("router: ", NA_Router);

    [owner, userWallet, anotherUser, sponsor1, sponsor2] = await getSigners();

    const chainId = parseInt(await getChainId(), 10);
    const upgrades = hre.upgrades;

    dim('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    dim('Smart Ecosystem Contracts - Deploy Script');
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

    const options = {
      deployBUSD: true,

      deploySmartComp: true,
      upgradeSmartComp: false,
      
      deployGoldenTreePool: true,
      upgradeGoldenTreePool: false,

      deploySmartNobilityAch: true,
      upgradeSmartNobilityAch: false,

      deploySmartOtherAch: true,
      upgradeSmartOtherAch: false,

      deploySmartArmy: true,
      upgradeSmartArmy: false,

      deploySmartFarm: true,
      upgradeSmartFarm: false,

      deploySmartLadder: true,
      upgradeSmartLadder: false,

      deploySMTBridge: true,

      deploySMTCashToken: true,

      resetSmartComp: false,

      deploySMTToken: true,

      testSMTTokenTransfer: true,

      testAddLiquidity: true,

      testArmyLicense: false,
      
      testUpgradeLicense: false,
      
      testSwap: false,

      testFarm: false
    }

    ///////////////////////// BUSD Token ///////////////////////////
    let BUSDAddress = NA_Busd;
    if(options.deployBUSD) {
      const BusdToken = await ethers.getContractFactory("BEP20Token");
      const busdContract = await BusdToken.deploy();
      await busdContract.deployed();
      BUSDAddress = busdContract.address;
      displayResult("\nBUSD token deployed at", busdContract);
    }
    let busdToken = await ethers.getContractAt("BEP20Token", BUSDAddress);

    ///////////////////////// SmartComp ///////////////////////
    let smartCompAddress = NA_SmartComp;
    const SmartComp = await ethers.getContractFactory('SmartComp');
    if(options.deploySmartComp) {
      cyan("Deploying SmartComp contract");
      const SmartCompProxy = await upgrades.deployProxy(
        SmartComp,
        [
            NA_Router,
            busdToken.address
        ],
        { initializer: 'initialize', kind: 'uups' }
      );
      await SmartCompProxy.deployed();
      displayResult('SmartComp Proxy', SmartCompProxy);
      
      smartCompAddress = SmartCompProxy.address;
    }
    if(!options.deploySmartComp && !options.upgradeSmartComp){
      green(`\nSmartComp Contract deployed at ${smartCompAddress}`);
    }
    const smartCompInstance = await ethers.getContractAt('SmartComp', smartCompAddress);

    ///////////////////////// SMTBridge ///////////////////////
    let uniswapV2Factory = await smartCompInstance.connect(owner).getUniswapV2Factory();    
    console.log("uniswapV2Factory:", uniswapV2Factory);

    let uniswapV2Router = await smartCompInstance.connect(owner).getUniswapV2Router();
    console.log("uniswapV2Router:", uniswapV2Router);

    let smtBridgeAddress = NA_SmartBridge;
    const SMTBridge = await ethers.getContractFactory('SMTBridge');
    if(options.deploySMTBridge) {
      cyan(`\nDeploying SMTBridge Contract...`);
      const SMTBridgeProxy = await upgrades.deployProxy(
        SMTBridge,
        [smartCompAddress],
        {
          initializer: 'initialize',
          kind: 'uups'
        }
      );
      await SMTBridgeProxy.deployed();
      displayResult('SMTBridge contract', SMTBridgeProxy);
      smtBridgeAddress = SMTBridgeProxy.address;
      tx = await smartCompInstance.connect(owner).setSmartBridge(smtBridgeAddress);
      await tx.wait();
      console.log("set SmartBridge to SmartComp: ", tx.hash);
    } else {
      green(`\SMTBridge Contract deployed at ${smtBridgeAddress}`);
    }

    const smartBridgeIns = await ethers.getContractAt("SMTBridge", smtBridgeAddress);
    ///////////////////////// Golden Tree Pool //////////////////// 
    let goldenTreePoolAddress = NA_GoldenTreePool;
    const GoldenTreePool = await ethers.getContractFactory('GoldenTreePool');
    if(options.deployGoldenTreePool) {
        cyan(`\nDeploying GoldenTreePool contract...`);
        const GoldenTreePoolProxy = await upgrades.deployProxy(
          GoldenTreePool,
            [smartCompAddress],
            {
              initializer: 'initialize',
              kind: 'uups'
            }
        );
        await GoldenTreePoolProxy.deployed();
        displayResult('GoldenTreePool Proxy Address:', GoldenTreePoolProxy);

        goldenTreePoolAddress = GoldenTreePoolProxy.address;

        let tx = await smartCompInstance.connect(owner).setGoldenTreePool(goldenTreePoolAddress);
        await tx.wait();
        console.log("set GoldenTreePool to SmartComp: ", tx.hash);
    }
    if(!options.deployGoldenTreePool && 
      !options.upgradeGoldenTreePool) {
      green(`\nGoldenTreePool Contract deployed at ${goldenTreePoolAddress}`);
    }
    const goldenTreePoolIns = await ethers.getContractAt("GoldenTreePool", goldenTreePoolAddress);

    ///////////////// Smart Nobility Archievement ////////////////////
    let smartNobilityAchAddress = NA_NobilityAch;
    const SmartNobilityAchievement = await ethers.getContractFactory('SmartNobilityAchievement');
    if(options.deploySmartNobilityAch) {
        cyan(`\nDeploying SmartNobilityAchievement Contract...`);
        const nobilityAchProxy = await upgrades.deployProxy(
          SmartNobilityAchievement,
            [smartCompAddress],
            {
              initializer: 'initialize',
              kind: 'uups'
            }
        );
        await nobilityAchProxy.deployed();
        displayResult('SmartNobilityAchievement Proxy Address:', nobilityAchProxy);
        smartNobilityAchAddress = nobilityAchProxy.address;

        tx = await smartCompInstance.connect(owner).setSmartNobilityAchievement(smartNobilityAchAddress);
        await tx.wait();
        console.log("set SmartNobilityAchievement to SmartComp: ", tx.hash);
    }
    if(options.upgradeSmartNobilityAch) {
      green(`\nUpgrading GoldenTreePool contract...`);
      await upgrades.upgradeProxy(smartNobilityAchAddress, SmartNobilityAchievement);
      green(`GoldenTreePool Contract Upgraded`);
    }
    if(!options.deploySmartNobilityAch && 
      !options.upgradeSmartNobilityAch) {
      green(`\nSmartNobilityAchievement Contract deployed at ${smartNobilityAchAddress}`);
    }
    const smartNobilityAchIns = await ethers.getContractAt('SmartNobilityAchievement', smartNobilityAchAddress);

    ///////////////// Smart Nobility Archievement ////////////////////
    let smartOtherAchAddress = NA_OtherAch;
    const SmartOtherAchievement = await ethers.getContractFactory('SmartOtherAchievement');
    if(options.deploySmartOtherAch) {
        cyan(`\nDeploying SmartOtherAchievement Contract...`);
        const otherAchProxy = await upgrades.deployProxy(
            SmartOtherAchievement,
            [smartCompAddress],
            {
              initializer: 'initialize',
              kind: 'uups'
            }
        );
        await otherAchProxy.deployed();
        displayResult('SmartOtherAchievement Proxy Address:', otherAchProxy);
        smartOtherAchAddress = otherAchProxy.address;

        tx = await smartCompInstance.connect(owner).setSmartOtherAchievement(smartOtherAchAddress);
        await tx.wait();
        console.log("set SmartOtherAchievement to SmartComp: ", tx.hash);
    }
    if(!options.deploySmartOtherAch && 
      !options.upgradeSmartOtherAch) {
      green(`\nSmartOtherAchievement Contract deployed at ${smartOtherAchAddress}`);
    }
    const smartOtherAchIns = await ethers.getContractAt('SmartOtherAchievement', smartOtherAchAddress);

    ///////////////// Smart Army //////////////////////
    let smartArmyAddress = NA_SmartArmy;
    const SmartArmy = await ethers.getContractFactory('SmartArmy');
    if(options.deploySmartArmy) {
        cyan(`\nDeploying SmartArmy contract...`);
        const SmartArmyContract = await upgrades.deployProxy(SmartArmy, 
            [smartCompAddress],
            {initializer: 'initialize',kind: 'uups'}
        );    
        await SmartArmyContract.deployed()        
        smartArmyAddress = SmartArmyContract.address;
        displayResult('SmartArmy Contract Address:', SmartArmyContract);

        let tx = await smartCompInstance.connect(owner).setSmartArmy(smartArmyAddress);
        await tx.wait();
        console.log("set SmartArmy to SmartComp: ", tx.hash);
    }
    if(options.upgradeSmartArmy) {
        green(`\nUpgrading SmartArmy contract...`);
        await upgrades.upgradeProxy(smartArmyAddress, SmartArmy);
        green(`Upgraded SmartArmy Contract`);
    }
    if(!options.deploySmartArmy && !options.upgradeSmartArmy) {
      green(`\nSmartArmy Contract deployed at ${smartArmyAddress}`);
    }
    const smartArmyIns = await ethers.getContractAt("SmartArmy", smartArmyAddress);

    ///////////////////// Smart Farm ////////////////////////
    let smartFarmAddress = NA_SmartFarm;
    const SmartFarm = await ethers.getContractFactory('SmartFarm');
    if(options.deploySmartFarm) {
        cyan(`\nDeploying SmartFarm contract...`);
        const SmartFarmContract = await upgrades.deployProxy(SmartFarm, 
            [smartCompAddress],
            {initializer: 'initialize',kind: 'uups'}
        );    
        await SmartFarmContract.deployed();        
        smartFarmAddress = SmartFarmContract.address;
        displayResult('SmartFarm Contract Address:', SmartFarmContract);

        let tx = await smartCompInstance.connect(owner).setSmartFarm(smartFarmAddress);
        await tx.wait();
        console.log("set SmartFarm to SmartComp: ", tx.hash);
    }
    if(options.upgradeSmartFarm) {
        green(`\nUpgrading SmartFarm contract...`);
        await upgrades.upgradeProxy(smartFarmAddress, SmartFarm);
        green(`SmartFarm Contract Upgraded`);
    }
    if(!options.deploySmartFarm && !options.upgradeSmartFarm) {
      green(`\nSmartFarm Contract deployed at ${smartFarmAddress}`);
    }
    const smartFarmIns = await ethers.getContractAt('SmartFarm', smartFarmAddress);

    ///////////////////////// Smart Ladder ///////////////////////////
    let smartLadderAddress = NA_SmartLadder;
    const SmartLadder = await ethers.getContractFactory('SmartLadder');
    if(options.deploySmartLadder) {
        cyan(`\nDeploying SmartLadder contract...`);
        SmartLadderContract = await upgrades.deployProxy(
          SmartLadder, 
          [smartCompAddress, owner.address],
          {initializer: 'initialize',kind: 'uups'}
        );    
        await SmartLadderContract.deployed()        
        smartLadderAddress = SmartLadderContract.address;
        displayResult('SmartLadder Contract Address:', SmartLadderContract);

        let tx = await smartCompInstance.connect(owner).setSmartLadder(smartLadderAddress);
        await tx.wait();
        console.log("set SmartLadder to SmartComp: ", tx.hash);
    }
    if(options.upgradeSmartLadder) {
        green(`\nUpgrading SmartLadder contract...`);
        await upgrades.upgradeProxy(smartLadderAddress, SmartLadder);
        green(`SmartLadder Contract Upgraded`);
    }
    if(!options.deploySmartLadder && !options.upgradeSmartLadder) {
        green(`\nSmartLadder Contract deployed at ${smartLadderAddress}`);
    }
    const smartLadderIns = await ethers.getContractAt('SmartLadder', smartLadderAddress);

    ///////////////////////// SmartTokenCash ///////////////////////
    let smtcAddress = NA_SMTC;
    if(options.deploySMTCashToken) {
      cyan(`\nDeploying SMTC Contract...`);
      const SmartTokenCash = await ethers.getContractFactory('SmartTokenCash');
      const SmartTokenCashContract = await upgrades.deployProxy(
        SmartTokenCash, 
        [
          smartCompAddress,
          owner.address,
          owner.address,
          owner.address
        ],
        {initializer: 'initialize',kind: 'uups'}
      );    
      await SmartTokenCashContract.deployed();
      smtcAddress = SmartTokenCashContract.address;
      displayResult('SmartTokenCash contract', SmartTokenCashContract);

      let tx = await smartCompInstance.connect(owner).setSMTC(smtcAddress);
      await tx.wait();
      console.log("set SmartTokenCash to SmartComp: ", tx.hash);
    }
    let smtcContract = await ethers.getContractAt("SmartTokenCash", smtcAddress);

    if(options.resetSmartComp) {
      let tx = await smartCompInstance.connect(owner).setSmartBridge(smtBridgeAddress);
      await tx.wait();
      console.log("set SmartBridge to SmartComp: ", tx.hash);
      
      tx = await smartCompInstance.connect(owner).setGoldenTreePool(goldenTreePoolAddress);
      await tx.wait();
      console.log("set GoldenTreePool to SmartComp: ", tx.hash);

      tx = await smartCompInstance.connect(owner).setSmartNobilityAchievement(smartNobilityAchAddress);
      await tx.wait();
      console.log("set SmartNobilityAchievement to SmartComp: ", tx.hash);

      tx = await smartCompInstance.connect(owner).setSmartOtherAchievement(smartOtherAchAddress);
      await tx.wait();
      console.log("set SmartOtherAchievement to SmartComp: ", tx.hash);

      tx = await smartCompInstance.connect(owner).setSmartArmy(smartArmyAddress);
      await tx.wait();
      console.log("set SmartArmy to SmartComp: ", tx.hash);

      tx = await smartCompInstance.connect(owner).setSmartFarm(smartFarmAddress);
      await tx.wait();
      console.log("set SmartFarm to SmartComp: ", tx.hash);

      tx = await smartCompInstance.connect(owner).setSmartLadder(smartLadderAddress);
      await tx.wait();
      console.log("set SmartLadder to SmartComp: ", tx.hash);
    }

    let smtTokenAddress = NA_SMT;
    if(options.deploySMTToken) {
        cyan(`\nDeploying SMT Token Contract...`);
        const SmartToken = await ethers.getContractFactory('SmartToken');
        const SmartTokenContract = await upgrades.deployProxy(
          SmartToken, 
          [
            smartCompAddress,
            owner.address,
            owner.address
          ],
          {initializer: 'initialize',kind: 'uups'}
        );  
        await SmartTokenContract.deployed();
        displayResult("\nSMT Token deployed at", SmartTokenContract);
    
        await displayWalletBalances(SmartTokenContract, true, false, false, false, false);

        smtTokenAddress = SmartTokenContract.address;    

        tx = await smartCompInstance.connect(owner).setSMT(SmartTokenContract.address);
        await tx.wait();
        console.log("set SMT token to SmartComp: ", tx.hash);

        tx = await SmartTokenContract.setTaxLockStatus(
            false, false, false, false, false, false
        );
        await tx.wait();
        console.log("set tax lock status:", tx.hash);

        tx = await smartLadderIns.initActivities();
        await tx.wait();
        console.log("initial activities: ", tx.hash);  

    } else {
      green(`\nSMT Token deployed at ${smtTokenAddress}`);
    }

    let smtContract = await ethers.getContractAt("SmartToken", smtTokenAddress);

    let router = await smartCompInstance.connect(owner).getUniswapV2Router();
    let routerInstance = new ethers.Contract(
        router, uniswapRouterABI, owner
    );

    if(options.testSMTTokenTransfer) {
        displayTitle("Token Transfer");

        let tranferTx =  await smtContract.transfer(
          anotherUser.address,
          ethers.utils.parseUnits("200000", 18)
        );
        await tranferTx.wait();
        console.log("SMT : owner -> another user transfer tx:", tranferTx.hash);
    
        tranferTx =  await smtContract.transfer(
          userWallet.address, 
          ethers.utils.parseUnits("200000", 18)
        );
        await tranferTx.wait();
        console.log("SMT : owner -> user transfer tx:", tranferTx.hash);
  
        tranferTx =  await busdToken.transfer(
          anotherUser.address, 
          ethers.utils.parseUnits("2000000", 18)
        );
        await tranferTx.wait();
        console.log("BUSD : owner -> another user transfer tx:", tranferTx.hash);
    
        tranferTx =  await busdToken.transfer(
          userWallet.address, 
          ethers.utils.parseUnits("2000000", 18)
        );
        await tranferTx.wait();
        console.log("BUSD : owner -> user transfer tx:", tranferTx.hash);      
        
        await displayWalletBalances(smtContract, true, true, true, false, false);
    }

    let pairSmtcBnbAddr = await smtContract._uniswapV2ETHPair();
    console.log("SMT-BNB LP token address: ", pairSmtcBnbAddr);
    let pairSmtcBusdAddr = await smtContract._uniswapV2BUSDPair();
    console.log("SMT-BUSD LP token address: ", pairSmtcBusdAddr);

    if(options.testAddLiquidity) {
        displayTitle("Add Liquidity");

        let router = await smartCompInstance.connect(owner).getUniswapV2Router();
        console.log("router: ", router);

        let pairSmtcBnbIns = new ethers.Contract(pairSmtcBnbAddr, uniswapPairABI, userWallet);
        let pairSmtcBusdIns = new ethers.Contract(pairSmtcBusdAddr, uniswapPairABI, userWallet);
  
        // %%  when adding liquidity, owner have to be called for initial liquidity first.
        await addLiquidityToPools(
          smtContract, busdToken, routerInstance, owner, 4000, 0.5, 100000, 100000
        );

        // await addLiquidityToPools(
        //   smtContract, busdToken, routerInstance, anotherUser, 100, 0.1, 15000, 15000
        // );

        await displayLiquidityPoolBalance("SMT-BNB Pool Reserves: ", pairSmtcBnbIns);
        await displayLiquidityPoolBalance("SMT-BUSD Pool Reserves: ", pairSmtcBusdIns);  
    }

    if(options.testArmyLicense) {
      displayTitle("Army License");
      let pairSmtcBusdAddr = await smtContract._uniswapV2BUSDPair();
      let pairSmtBusdIns = new ethers.Contract(pairSmtcBusdAddr, uniswapPairABI, owner);
      await displayLiquidityPoolBalance("SMT-BUSD POOL:", pairSmtBusdIns);
      await displayWalletBalances(smtContract, false, false, true, false, false);

      let smtAddr = await smartCompInstance.connect(owner).getSMT();
      let farmAddr = await smartCompInstance.connect(owner).getSmartFarm();
      console.log("smt address: ", smtAddr);
      console.log("farm address: ", farmAddr);

      expect(await smartCompInstance.connect(owner).getSMT()).to.equal(smtContract.address);
      expect(await smartCompInstance.connect(owner).getSmartFarm()).to.equal(smartFarmAddress);

      await displayAllLicense(smartArmyIns);
      await buyLicense(smtContract, smartArmyIns, userWallet, owner);
      await displayLicenseOf(smartArmyIns, userWallet.address);
      await displayWalletBalances(smtContract, false, false, true, false, false);
    }

    if(options.testUpgradeLicense){
      displayTitle("Upgrade License");

      let tx =  await smtContract.transfer(
        sponsor1.address, 
        ethers.utils.parseUnits("10000", 18)
      );
      await tx.wait();
      console.log("SMT : owner -> sponsor1 transfer tx:", tx.hash);

      tx =  await smtContract.transfer(
        sponsor2.address, 
        ethers.utils.parseUnits("10000", 18)
      );
      await tx.wait();
      console.log("SMT : owner -> sponsor2 transfer tx:", tx.hash);

      await buyLicense(smtContract, smartArmyIns, anotherUser, userWallet);
      await buyLicense(smtContract, smartArmyIns, sponsor1, anotherUser);
      await buyLicense(smtContract, smartArmyIns, sponsor2, sponsor1);

      await displayLicenseOf(smartArmyIns, userWallet.address);
      await displayLicenseOf(smartArmyIns, anotherUser.address);
      await displayLicenseOf(smartArmyIns, sponsor1.address);
      await displayLicenseOf(smartArmyIns, sponsor2.address);

      await displayWalletBalances(smtContract, true, true, true, true, true);

      tx =  await smtContract.connect(userWallet).transfer(
        anotherUser.address, 
        ethers.utils.parseUnits("100", 18)
      );
      await tx.wait();
      console.log("SMT : userWallet -> anotherUser transfer tx:", tx.hash);

      tx =  await smtContract.connect(anotherUser).transfer(
        sponsor1.address, 
        ethers.utils.parseUnits("500", 18)
      );
      await tx.wait();
      console.log("SMT : anotherUser -> sponsor1 transfer tx:", tx.hash);

      tx =  await smtContract.connect(sponsor1).transfer(
        sponsor2.address, 
        ethers.utils.parseUnits("1000", 18)
      );
      await tx.wait();
      console.log("SMT : sponsor1 -> sponsor2 transfer tx:", tx.hash);

    }

    if(options.testSwap) {
      let isIntermediary = await smtContract.enabledIntermediary(anotherUser.address);
      console.log("is allowed license: ", isIntermediary);

      let swapAmount = 100;
      let tx = await smtContract.connect(anotherUser).approve(
        smartBridgeIns.address,
          ethers.utils.parseUnits(Number(swapAmount+1).toString(), 18)
      );
      await tx.wait();
      console.log("approved tx: ", tx.hash);

      let amountIn = ethers.utils.parseUnits(Number(swapAmount).toString(), 18);
      console.log("amountIn: ", amountIn);
      tx = await smartBridgeIns.connect(anotherUser).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        amountIn,
        0,
        [
          smtContract.address,
          busdToken.address
        ],
        anotherUser.address,
        "99000000000000000000"
      );
      await tx.wait();
      console.log("Tx swapped for BUSD via SMT Bridge: ", tx.hash);

      tx = await smtContract.connect(anotherUser).approve(
        smartBridgeIns.address,
          ethers.utils.parseUnits(Number(swapAmount+1).toString(), 18)
      );
      await tx.wait();
      console.log("approved tx: ", tx.hash);

      let wBNBAddress = await routerInstance.WETH();
      tx = await smartBridgeIns.connect(anotherUser).swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountIn,
        0,
        [
          smtContract.address,          
          wBNBAddress
        ],
        anotherUser.address,
        "99000000000000000000"
      );
      await tx.wait();
      console.log("Tx swapped for BNB via SMT Bridge: ", tx.hash);      
    }

  }

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
