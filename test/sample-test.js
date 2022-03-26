const { expect } = require("chai");
const { ethers, getNamedAccounts, deployments } = require("hardhat");
const chalk = require('chalk');
const { deploy } = deployments;

// const uniswapRouterABI = require("../artifacts/contracts/interfaces/IUniswapRouter.sol/IUniswapV2Router02.json").abi;
const uniswapRouterABI = require("../artifacts/contracts/libs/dexRouter.sol/IPancakeSwapRouter.json").abi;
const uniswapPairABI = require("../artifacts/contracts/libs/dexfactory.sol/IPancakeSwapPair.json").abi;

let owner, user, anotherUser, farmRewardWallet;
let exchangeFactory;
let wEth;
let exchangeRouter;
let smtcContract;
let busdContract;
let smartCompContract;
let smartFarmContract;
let smartArmyContract;
let smartLadderContract;
let goldenTreeContract;
let smartAchievementContract;
let routerInstance;
let smartBridge;
let initCodePairHash;
let enabledFactoryOption = false;
const upgrades = hre.upgrades;

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

const displayWalletBalances = async(tokenIns, bOwner, bAnother, bUser, bFarmingReward) => {
  let count = 0;
  if(bOwner){
    let balance = await tokenIns.balanceOf(owner.address);
    console.log("owner balance:",
                ethers.utils.formatEther(balance.toString()));
    count++;
  }
  if(bAnother){
    let balance = await tokenIns.balanceOf(anotherUser.address);
    console.log("another user balance:",
                ethers.utils.formatEther(balance.toString()));
    count++;
  }
  if(bUser){
    let balance = await tokenIns.balanceOf(user.address);
    console.log("user balance:",
                ethers.utils.formatEther(balance.toString()));
    count++;
  }
  if(bFarmingReward){
    let balance = await tokenIns.balanceOf(farmRewardWallet.address);
    console.log("farming reward wallet balance:",
                ethers.utils.formatEther(balance.toString()));
    count++;
  }
  if(count > 0)
    green("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
};

const displayUserInfo = async(farmContract, wallet) => {
  let info = await farmContract.userInfoOf(wallet.address);
  cyan("-------------------------------------------");
  console.log("balance of wallet:", ethers.utils.formatEther(info.balance));
  console.log("rewards of wallet:", info.rewards.toString());
  console.log("reward per token paid of wallet:", info.rewardPerTokenPaid.toString());
  console.log("last updated time of wallet:", info.balance.toString());
}

const displayLiquidityPoolBalance = async(comment, poolInstance) => {
  let reservesPair = await poolInstance.getReserves();
  console.log(comment);
  console.log("token0:", ethers.utils.formatEther(reservesPair.reserve0));
  console.log("token1:", ethers.utils.formatEther(reservesPair.reserve1));
}

const addLiquidityToPools = async(
  tokenA, tokenB,
  routerInstance, walletIns,
  smtAmount1, bnbAmount, 
  smtAmount2, busdAmount
) => {
  ///////////////////  SMT-BNB Add Liquidity /////////////////////
  let tx = await tokenA.connect(walletIns).approve(
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

const swapSMTForBNB = async(
  pairInstance,
  inputTokenIns, 
  wallet,
  routerInstance,
  swapAmount
) => {
      console.log("----------------------- Swap SMT For BNB ---------------------");
      await displayLiquidityPoolBalance("SMT-BNB Pool:", pairInstance);

      let balance = await ethers.provider.getBalance(wallet.address);
      console.log(">>> old balance: ", ethers.utils.formatEther(balance));

      let tx = await inputTokenIns.connect(wallet).approve(
          routerInstance.address,
          ethers.utils.parseUnits(Number(swapAmount+100).toString(), 18)
      );
      await tx.wait();
      let amountIn = ethers.utils.parseUnits(Number(swapAmount).toString(), 18);
      let wEth = await routerInstance.WETH();
      let amountsOut = await routerInstance.getAmountsOut(
        amountIn,
        [ inputTokenIns.address, wEth ]
      );
      console.log("excepted swap balance: ", ethers.utils.formatEther(amountsOut[1]));

      tx = await routerInstance.connect(wallet).swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountIn, 0,
        [ inputTokenIns.address, wEth ],
        wallet.address,
        "990000000000000000000"
      );
      await tx.wait();
      balance = await ethers.provider.getBalance(wallet.address);
      console.log(">>> new balance: ", ethers.utils.formatEther(balance));
      await displayLiquidityPoolBalance("SMT-BNB Pool:", pairInstance);
}

const swapSMTForBUSD = async(
  pairInstance,
  inputTokenIns,
  outTokenIns,
  wallet,
  routerInstance,
  swapAmount
) => {
      console.log("----------------------- Swap SMT For BUSD ---------------------");
      await displayLiquidityPoolBalance("SMT-BUSD Pool:", pairInstance);

      let balance = await outTokenIns.balanceOf(wallet.address);
      console.log(">>> old balance by BUSD: ", ethers.utils.formatEther(balance));

      let tx = await inputTokenIns.connect(wallet).approve(
          routerInstance.address,
          ethers.utils.parseUnits(Number(swapAmount+100).toString(), 18)
      );
      await tx.wait();
      let amountIn = ethers.utils.parseUnits(Number(swapAmount).toString(), 18);
      let amountsOut = await routerInstance.getAmountsOut(
        amountIn,
        [
          inputTokenIns.address, 
          outTokenIns.address
        ]
      );
      console.log("excepted swap balance: ", ethers.utils.formatEther(amountsOut[1]));

      tx = await routerInstance.connect(wallet).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        amountIn,
        0,
        [
          inputTokenIns.address,
          outTokenIns.address
        ],
        wallet.address,
        "99000000000000000000"
      );
      await tx.wait();

      balance = await outTokenIns.balanceOf(wallet.address);
      console.log(">>> new balance by BUSD: ", ethers.utils.formatEther(balance));
      await displayLiquidityPoolBalance("SMT-BUSD Pool:", pairInstance);
}

const registerToLicense = async(smtTokenIns, smartArmyContract, wallet) => {
  cyan("============= Register Licenses =============");
  let userBalance = await smtTokenIns.balanceOf(wallet.address);
  userBalance = ethers.utils.formatEther(userBalance);
  const license = await smartArmyContract.licenseTypeOf(1);
  let price = ethers.utils.formatEther(license.price);
  if(userBalance < price) {        
    console.log("charge SMT token to your wallet!!!!");
    return;
  }

  let tx = await smartArmyContract.connect(wallet).registerLicense(
    1, wallet.address, "Arsenii", "https://t.me.Ivan"
  );
  await tx.wait();
  console.log("License register transaction:", tx.hash);

  tx = await smtTokenIns.connect(wallet).approve(
    smartArmyContract.address,
    ethers.utils.parseUnits(Number(price).toString(), 18)
  );
  await tx.wait();

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

describe("Smtc Ecosystem Contracts Audit", () => {
  const { getContractFactory, getSigners } = ethers;

  beforeEach(async () => {
    [owner, user, anotherUser, farmRewardWallet] = await getSigners();
  });

  describe("Dex Engine Deploy", () => {

    it("Factory deploy", async function () {
      console.log("owner:", owner.address);
      console.log("user:", user.address);
      console.log("another user:", anotherUser.address);

      cyan(`\nDeploying Factory Contract...`);

      // const factoryAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
      // if(enabledFactoryOption){
      const Factory = await ethers.getContractFactory("PancakeSwapFactory");      
      exchangeFactory = await Factory.deploy(owner.address);
      await exchangeFactory.deployed();
      initCodePairHash = await exchangeFactory.INIT_CODE_PAIR_HASH();
      console.log("INIT_CODE_PAIR_HASH: ", initCodePairHash);  
      // }
      // exchangeFactory = await ethers.getContractAt("PancakeSwapFactory", factoryAddress);
      displayResult("\nMy Factory deployed at", exchangeFactory);
    });
  
    it("WETH deploy", async function () {
      cyan(`\nDeploying WETH Contract...`);
      const wETH = await ethers.getContractFactory("WETH");
      wEth = await wETH.deploy();
      await wEth.deployed();
      displayResult("\nMy WETH deployed at", wEth);
    });
    
    it("Router deploy", async function () {
      cyan(`\nDeploying Router Contract...`);
      const Router = await ethers.getContractFactory("PancakeSwapRouter");
      exchangeRouter = await Router.deploy(exchangeFactory.address, wEth.address);
      await exchangeRouter.deployed();
      displayResult("\nMy Router deployed at", exchangeRouter);
    });

  });

  describe("Main Contract Deploy", () => {

    it("SMTC Token Deploy...", async function () {
      cyan(`\nDeploying SmartTokenCash Contract...`);
      const SmartTokenCash = await ethers.getContractFactory("SmartTokenCash");
      smtcContract = await SmartTokenCash.deploy();
      await smtcContract.deployed();    
      displayResult("\nSmartTokenCash deployed at", smtcContract);
    });

    it("BUSD Token Deploy...", async function () {
      cyan(`\nDeploying BUSD Contract...`);
      const BusdToken = await ethers.getContractFactory("BEP20Token");
      busdContract = await BusdToken.deploy();
      await busdContract.deployed();    
      displayResult("\nBUSD token deployed at", busdContract);
    });

    it("SmartComp Deploy...", async function () {
      cyan(`\nDeploying SmartComp Contract...`);
      // console.log("upgrades:", upgrades);
      const SmartComp = await ethers.getContractFactory('SmartComp');
      smartCompContract = await upgrades.deployProxy(
        SmartComp, 
        [
          exchangeRouter.address,
          busdContract.address
        ],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartCompContract.deployed();
      displayResult('SmartComp contract', smartCompContract);
      let smartCompInstance = await ethers.getContractAt("SmartComp", smartCompContract.address);
      let busdAddr = await smartCompInstance.getBUSD();
      yellow(`\n busd address: ${busdAddr}`);
      tx = await smartCompContract.setBUSD(busdAddr);
      await tx.wait();
      console.log("setting busd token:", tx.hash);
      let bnbAddr = await smartCompContract.getWBNB();
      yellow(`\n bnb address: ${bnbAddr}`);
    });

    it("SMTBridge deploy", async function () {
      cyan(`\nDeploying SMTBridge Contract...`);
      const SmartBridge = await ethers.getContractFactory("SMTBridge");
      smartBridge = await SmartBridge.deploy(
        smartCompContract.address
      );
      await smartBridge.deployed();
      displayResult('SMTBridge contract', smartBridge);
    });

    it("SmartArmy Deploy...", async() => {
      cyan(`\nDeploying SmartArmy Contract...`);
      const SmartArmy = await ethers.getContractFactory('SmartArmy');
      smartArmyContract = await upgrades.deployProxy(
        SmartArmy, 
        [smartCompContract.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartArmyContract.deployed();
      displayResult('SmartArmy contract', smartArmyContract);
    });

    it("SmartLadder Deploy...", async() => {
      cyan(`\nDeploying SmartLadder Contract...`);
      const SmartLadder = await ethers.getContractFactory('SmartLadder');
      smartLadderContract = await upgrades.deployProxy(
        SmartLadder, 
        [smartCompContract.address, owner.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartLadderContract.deployed();
      displayResult('SmartLadder contract', smartLadderContract);
    });

    it("SmartFarm Deploy...", async function () {
      cyan(`\nDeploying SmartFarm Contract...`);
      // console.log("upgrades:", upgrades);
      const SmartFarm = await ethers.getContractFactory('SmartFarm');
      smartFarmContract = await upgrades.deployProxy(
        SmartFarm, 
        [smartCompContract.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartFarmContract.deployed();
      displayResult('SmartFarm contract', smartFarmContract);

      let tx = await smartFarmContract.connect(owner).addDistributor(user.address);
      await tx.wait();
      tx = await smartFarmContract.connect(owner).addDistributor(anotherUser.address);
      await tx.wait();

    });
    
    it("GoldenTreePool Deploy...", async function() {
      cyan(`\nDeploying GoldenTreePool Contract...`);
      const GoldenTreePool = await ethers.getContractFactory('GoldenTreePool');
      goldenTreeContract = await upgrades.deployProxy(
        GoldenTreePool, 
        [smartCompContract.address, smtcContract.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await goldenTreeContract.deployed();
      displayResult('GoldenTreePool contract', goldenTreeContract);
    });

    it("SmartAchievement Deploy...", async function() {
      cyan(`\nDeploying SmartAchievement Contract...`);
      const SmartAchievement = await ethers.getContractFactory('SmartAchievement');
      smartAchievementContract = await upgrades.deployProxy(
        SmartAchievement, 
        [smartCompContract.address, smtcContract.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartAchievementContract.deployed();
      displayResult('SmartAchievement contract', smartAchievementContract);
    });

    it("Setting main contracts addresses to smart comp", async() => {
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);
      let tx = await smtcCompIns.setSmartBridge(smartBridge.address);
      await tx.wait();
      console.log("setted smart bridge to smart comp: ", tx.hash);
      tx = await smtcCompIns.setSmartLadder(smartLadderContract.address);
      await tx.wait();
      console.log("setted smart ladder to smart comp: ", tx.hash);
      tx = await smtcCompIns.setSmartArmy(smartArmyContract.address);
      await tx.wait();
      console.log("setted smart army to smart comp: ", tx.hash);
      tx = await smtcCompIns.setSmartFarm(smartFarmContract.address);
      await tx.wait();
      console.log("setted smart farm to smart comp: ", tx.hash);
      tx = await smtcCompIns.setGoldenTreePool(goldenTreeContract.address);
      await tx.wait();
      console.log("setted golden tree pool to smart comp: ", tx.hash);
      tx = await smtcCompIns.setSmartAchievement(smartAchievementContract.address);
      await tx.wait();
      console.log("setted smart achievement to smart comp: ", tx.hash);
    });
    
    it("SMT Token Deploy....", async() => {
      cyan(`\nDeploying SMT Token Contract...`);

      expect(await smartCompContract.getUniswapV2Router())
                        .to.equal(exchangeRouter.address);

      smtContract = await deploy('SMT', {
        from: owner.address,
        args: [
          smartCompContract.address,
          owner.address,
          owner.address
        ]
      });
      displayResult("\nSMT Token deployed at", smtContract);

      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      await displayWalletBalances(smtTokenIns, true, false, false, false);
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);

      tx = await smtcCompIns.setSMT(smtcContract.address);
      await tx.wait();
      console.log("set SMT token to SmartComp: ", tx.hash);

      tx = await smtTokenIns.setSmartComp(smartCompContract.address);
      await tx.wait();
      console.log("set smart comp to token: ", tx.hash);

      tx = await smtTokenIns.setSmartArmyAddress(smartArmyContract.address);
      await tx.wait();
      console.log("set smart army to token: ", tx.hash);

      tx = await smtTokenIns.setTaxLockStatus(
        false, false, false, false, false, false
      );
      await tx.wait();
      console.log("set tax lock status to token: ", tx.hash);

      let bal = await smtTokenIns.balanceOf(owner.address);
      console.log("owner SMT balance:", ethers.utils.formatEther(bal.toString()));
      bal = await busdContract.balanceOf(owner.address);
      console.log("owner BUSD balance:", ethers.utils.formatEther(bal.toString()));
    });

    it("Token Transfer 00...", async() => {
      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      await displayWalletBalances(smtTokenIns, false, false, false, true); 
      await displayWalletBalances(busdContract, false, false, false, true); 

      let tranferTx =  await smtTokenIns.transfer(
        anotherUser.address,
        ethers.utils.parseUnits("30000", 18)
      );
      await tranferTx.wait();

      tranferTx =  await smtTokenIns.transfer(
        user.address,
        ethers.utils.parseUnits("30000", 18)
      );
      await tranferTx.wait();

      tranferTx =  await busdContract.transfer(
        anotherUser.address,
        ethers.utils.parseUnits("20000", 18)
      );
      await tranferTx.wait();

      tranferTx =  await busdContract.transfer(
        user.address,
        ethers.utils.parseUnits("20000", 18)
      );
      await tranferTx.wait();

      await displayWalletBalances(smtTokenIns, false, true, true, false); 
      await displayWalletBalances(busdContract, false, true, true, false); 
    });

    it("Add liquidity to liquidity pools...", async() => {
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);  
      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      routerInstance = new ethers.Contract(
        smtcCompIns.getUniswapV2Router(), uniswapRouterABI, owner
      );
      let pairSmtcBnbAddr = await smtTokenIns._uniswapV2ETHPair();
      console.log("SMT-BNB LP token address: ", pairSmtcBnbAddr);
      let pairSmtcBusdAddr = await smtTokenIns._uniswapV2BUSDPair();
      console.log("SMT-BUSD LP token address: ", pairSmtcBusdAddr);
      let pairSmtBnbIns = new ethers.Contract(pairSmtcBnbAddr, uniswapPairABI, owner);
      let pairSmtBusdIns = new ethers.Contract(pairSmtcBusdAddr, uniswapPairABI, owner);

      let tx = await smtTokenIns.setTaxLockStatus(
        false, true, false, false, true, false
      );
      await tx.wait();

      tx = await smtcCompIns.setSMT(smtTokenIns.address);
      await tx.wait();

      await addLiquidityToPools(
        smtTokenIns, busdContract, routerInstance, owner, 10000, 10, 10000, 10000
      );
      await displayLiquidityPoolBalance("SMT-BNB Pool Reserves: ", pairSmtBnbIns);
      await displayLiquidityPoolBalance("SMT-BUSD Pool Reserves: ", pairSmtBusdIns);
      console.log("###### successful addition liquidity by owner");

      await addLiquidityToPools(
        smtTokenIns, busdContract, routerInstance, anotherUser, 1000, 10, 1000, 1000
      );
      await displayLiquidityPoolBalance("SMT-BNB Pool Reserves: ", pairSmtBnbIns);
      await displayLiquidityPoolBalance("SMT-BUSD Pool Reserves: ", pairSmtBusdIns);
      console.log("###### successful addition liquidity by another user");

      await addLiquidityToPools(
        smtTokenIns, busdContract, routerInstance, user, 5000, 10, 5000, 5000
      );
      await displayLiquidityPoolBalance("SMT-BNB Pool Reserves: ", pairSmtBnbIns);
      await displayLiquidityPoolBalance("SMT-BUSD Pool Reserves: ", pairSmtBusdIns);
      console.log("###### successful addition liquidity by user");      

    });

    it("Swap Exchange...", async() => {
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);  
      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      let pairSmtcBnbAddr = await smtTokenIns._uniswapV2ETHPair();
      let pairSmtcBusdAddr = await smtTokenIns._uniswapV2BUSDPair();
      let pairSmtBnbIns = new ethers.Contract(pairSmtcBnbAddr, uniswapPairABI, owner);
      let pairSmtBusdIns = new ethers.Contract(pairSmtcBusdAddr, uniswapPairABI, owner);

      routerInstance = new ethers.Contract(
        smtcCompIns.getUniswapV2Router(), uniswapRouterABI, owner
      );
      
      await swapSMTForBNB(pairSmtBnbIns, smtTokenIns, user, routerInstance, 500);
      await swapSMTForBUSD(pairSmtBusdIns, smtTokenIns, busdContract, anotherUser, routerInstance, 1000);

    });

    it("Token Transfer 11...", async() => {
      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      let tranferTx = await smtTokenIns.connect(anotherUser).transfer(
        user.address, 
        ethers.utils.parseUnits("1000", 18)
      );
      await tranferTx.wait();
      console.log("another user -> user transfer tx:", tranferTx.hash);
      await displayWalletBalances(smtTokenIns, false, true, false, true);

      tranferTx = await smtTokenIns.transfer(
        user.address,
        ethers.utils.parseUnits("3000", 18)
      );
      console.log("owner -> user: ", tranferTx.hash);
    });

    it("SmartArmy ###  fetch all licenses", async() => {
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
    });

    it("SmartArmy ### register and active license", async() => {
      cyan("============= Register Licenses =============");
      let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
      let userBalance = await smtTokenIns.balanceOf(user.address);
      userBalance = ethers.utils.formatEther(userBalance);
      const license = await smartArmyContract.licenseTypeOf(1);
      let price = ethers.utils.formatEther(license.price);
      if(userBalance < price) {        
        console.log("charge SMT token to your wallet!!!!");
        return;
      }

      let tx = await smartArmyContract.connect(user).registerLicense(
        1, anotherUser.address, "Arsenii", "https://t.me.Ivan", "https://ipfs/21232df233"
      );
      await tx.wait();
      console.log("register transaction:", tx.hash);

      tx = await smtTokenIns.connect(user).approve(
        smartArmyContract.address,
        ethers.utils.parseUnits(Number(price).toString(), 18)
      );
      await tx.wait();
      console.log("approve tx: ", tx.hash);
      
      tx = await smartArmyContract.connect(user).activateLicense();
      await tx.wait();
      console.log("transaction: ", tx.hash);
      
      await displayWalletBalances(smtTokenIns, false, false, true, false);
      let userLic = await smartArmyContract.licenseOf(user.address);
      console.log("----------- user license ---------------");
      console.log("owner: ", userLic.owner);
      console.log("level: ", userLic.level.toString());
      console.log("start at: ", userLic.startAt.toString());
      console.log("active at: ", userLic.activeAt.toString());
      console.log("expire at: ", userLic.expireAt.toString());
      console.log("lp locked: ", ethers.utils.formatEther(userLic.lpLocked.toString()));
    });

    // it("SmartArmy ### liquidate license", async() => {
    //   let userLic = await smartArmyContract.licenseOf(user.address);
    //   let curBlockNumber = await ethers.provider.getBlockNumber();
    //   const timestamp = (await ethers.provider.getBlock(curBlockNumber)).timestamp;
      
    //   if(userLic.expireAt > timestamp) {
    //     console.log("Current License still active!!!");
    //     return;
    //   }

    //   let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
    //   displayWalletBalances(smtTokenIns,false,false,true,false);

    //   let tx = await smartArmyContract.connect(user).liquidateLicense();
    //   await tx.wait();

    //   displayWalletBalances(smtTokenIns,false,false,true,false);
    // });

    // it("SmartArmy ### extend license", async() => {

    //   let userLic = await smartArmyContract.connect(user).licenseOf(user.address);
    //   let curBlockNumber = await ethers.provider.getBlockNumber();
    //   const timestamp = (await ethers.provider.getBlock(curBlockNumber)).timestamp;
      
    //   if(userLic.expireAt > timestamp) {
    //     console.log("Current License still active!!!");
    //     return;
    //   }

    //   let info = await smartArmyContract.feeInfo();
    //   let balance = await ethers.provider.getBalance(user.address);
    //   console.log("bnb balance of user:",ethers.utils.formatEther(balance.toString()));

    //   let tx = await smartArmyContract.connect(user)
    //           .extendLicense({value: info.extendFeeBNB});
    //   await tx.wait();

    //   balance = await ethers.provider.getBalance(user.address);
    //   console.log("bnb balance of user:",ethers.utils.formatEther(balance.toString()));

    //   console.log("----------- user license ---------------");
    //   console.log("start at: ", userLic.startAt.toString());
    //   console.log("active at: ", userLic.activeAt.toString());
    //   console.log("expire at: ", userLic.expireAt.toString());
    // });

    // it("SmartFarming ### add distributor and notify new rewards", async() => {
    //   cyan("--------------------------------------");

    //   let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
    //   displayWalletBalances(smtTokenIns, false, false, true, true);

    //   tx = await smtTokenIns.connect(user).transfer(
    //     smartFarmContract.address, 
    //     ethers.utils.parseUnits('1000',18)
    //   );
    //   await tx.wait();

    //   tx = await smartFarmContract.connect(user).notifyRewardAmount(ethers.utils.parseUnits('1000',18));
    //   await tx.wait();

    //   let rewardRate = await smartFarmContract.rewardRate();
    //   console.log("first reward rate: %s",rewardRate.toString());

    //   displayWalletBalances(smtTokenIns, false, false, true, true);
    // });

    // it("SmartFarming ### staking SMT token", async() => {
    //   let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
    //   await displayWalletBalances(smtTokenIns, true, true, true);
    //   let tx = await smtTokenIns.connect(user).approve(
    //     smartFarmContract.address,
    //     ethers.utils.parseUnits('1000',18)
    //   );
    //   await tx.wait();

    //   tx = await smartFarmContract.connect(user)
    //                 .stakeSMT(
    //                   user.address, 
    //                   ethers.utils.parseUnits('1000', 18)
    //                 );
    //   await tx.wait();

    //   await displayWalletBalances(smtTokenIns, false, false, true);

    //   await displayUserInfo(smartFarmContract, user);

    //   tx = await smtTokenIns.connect(user).approve(
    //     smartFarmContract.address,
    //     ethers.utils.parseUnits('1000',18)
    //   );
    //   await tx.wait();

    //   tx = await smartFarmContract.connect(user)
    //               .stakeSMT(
    //                 user.address,
    //                 ethers.utils.parseUnits('1000',18)
    //               );
    //   await tx.wait();

    //   await displayWalletBalances(smtTokenIns, false, false, true);
    //   await displayUserInfo(smartFarmContract, user);

    //   let rewardRate = await smartFarmContract.rewardRate();
    //   console.log("current reward rate: %s", rewardRate.toString());

    // });

    // it('SmartFarming ### withdraw SMT token and claim Reward', async() => {
    //   let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
    //   await displayWalletBalances(smtTokenIns, true, true, true);

    //   tx = await smartFarmContract.connect(user).withdrawSMT(user.address, ethers.utils.parseUnits('500', 18));
    //   await tx.wait();
    //   console.log("withdrawed smt token in farming pool: ", tx.hash);

    //   await displayWalletBalances(smtTokenIns, false, false, true);
    //   await displayUserInfo(smartFarmContract, user);

    //   let rewards = await smartFarmContract.rewardsOf(user.address);
    //   tx = await smtTokenIns.connect(farmRewardWallet).approve(smartFarmContract.address, rewards);
    //   await tx.wait();
    //   console.log("approved farming wallet --> farming contract: ", tx.hash);
    //   tx = await smartFarmContract.connect(user).claimReward();
    //   await tx.wait();
    //   console.log("claimed reward in farming pool: ", tx.hash);
    // });

    // it('SMTBridge ### swapping test', async() => {
    //   let smtTokenIns = await ethers.getContractAt("SMT", smtContract.address);
    //   let pairSmtcBusdAddr = await smtTokenIns._uniswapV2BUSDPair();
    //   let pairSmtBusdIns = new ethers.Contract(pairSmtcBusdAddr, uniswapPairABI, owner);
    //   await displayLiquidityPoolBalance("SMT-BUSD POOL:", pairSmtBusdIns);
    //   await displayWalletBalances(smtTokenIns, false, true, false, false);

    //   await displayLicenseOf(smartArmyContract, user.address);
    //   // await registerToLicense(smtTokenIns, smartArmyContract, user);

    //   let isIntermediary = await smtTokenIns.enabledIntermediary(user.address);
    //   console.log("is allowed license: ", isIntermediary);

    //   let swapAmount = 100;
    //   let tx = await smtTokenIns.connect(user).approve(
    //       smartBridge.address,
    //       ethers.utils.parseUnits(Number(swapAmount+1).toString(), 18)
    //   );
    //   await tx.wait();
    //   console.log("approved tx: ", tx.hash);

    //   let amountIn = ethers.utils.parseUnits(Number(swapAmount).toString(), 18);
    //   console.log("amountIn: ", amountIn);
    //   tx = await smartBridge.connect(user).swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     amountIn,
    //     0,
    //     [
    //       smtTokenIns.address,
    //       busdContract.address
    //     ],
    //     user.address,
    //     "99000000000000000000"
    //   );
    //   await tx.wait();
    //   console.log("swapping tx: ", tx.hash);
    // });

    it("SmartLadder### ", async() => {
      
    });
  });
});