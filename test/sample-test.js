const { expect } = require("chai");
const { ethers, getNamedAccounts, deployments } = require("hardhat");
const chalk = require('chalk');
const { deploy } = deployments;

// const uniswapRouterABI = require("../artifacts/contracts/interfaces/IUniswapRouter.sol/IUniswapV2Router02.json").abi;
const uniswapRouterABI = require("../artifacts/contracts/libs/dexRouter.sol/IPancakeSwapRouter.json").abi;
const bep20ABI = require("../artifacts/contracts/libs/IBEP20.sol/IBEP20.json").abi;

let owner, user, anotherUser, wallet1;
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

const displayWalletBalances = async (tokenIns, bOwner, bAnother, bUser, bWallet) => {
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
    let balance = await tokenIns.balanceOf(user.address);
    console.log("user balance:",
                ethers.utils.formatEther(balance.toString()));  
  }

  if(bWallet){
    let balance = await tokenIns.balanceOf(wallet1.address);
    console.log("wallet1 balance:",
                ethers.utils.formatEther(balance.toString()));  
  }
};

describe("Smtc Ecosystem Contracts Audit", () => {
  const { getContractFactory, getSigners } = ethers;

  beforeEach(async () => {
    [owner, user, anotherUser, wallet1] = await getSigners();
  });

  describe("Dex Engine Deploy", () => {

    it("Factory deploy", async function () {
      console.log("owner:", owner.address);
      console.log("user:", user.address);
      console.log("another user:", anotherUser.address);
      console.log("wallet1:", wallet1.address);

      cyan(`\nDeploying Factory Contract...`);
      const Factory = await ethers.getContractFactory("PancakeSwapFactory");
      exchangeFactory = await Factory.deploy(owner.address);
      await exchangeFactory.deployed();
      displayResult("\nMy Factory deployed at", exchangeFactory);
      console.log(await exchangeFactory.INIT_CODE_PAIR_HASH());
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
        SmartComp, [],
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
      tx = await smartCompContract.setUniswapRouter(exchangeRouter.address);
      await tx.wait();
      console.log("setting uniswap:", tx.hash);
      let bnbAddr = await smartCompContract.getWBNB();
      yellow(`\n bnb address: ${bnbAddr}`);
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
        [smartCompContract.address, owner.address],
        { initializer: 'initialize', kind: 'uups' }
      );
      await smartFarmContract.deployed();
      displayResult('SmartFarm contract', smartFarmContract);
    });
    
    it("GoldenTreePool Deploy...", async function() {
      cyan(`\nDeploying GoldenTreePool Contract...`);
      // console.log("upgrades:", upgrades);
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
      // console.log("upgrades:", upgrades);
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
      let tx = await smtcCompIns.setBUSD(busdContract.address);
      await tx.wait();
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
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);
      cyan(`\nDeploying SMT Token Contract...`);
      smtContract = await deploy('SmartToken', {
        from: owner.address,
        args: [
          exchangeRouter.address,
          await smtcCompIns.getBUSD(),
          await smtcCompIns.getSmartLadder(),
          await smtcCompIns.getGoldenTreePool(),
          owner.address,
          await smtcCompIns.getSmartAchievement(),
          await smtcCompIns.getSmartFarm(),
          user.address,
          await smtcCompIns.getSmartArmy(),
          smartCompContract.address,
          owner.address
        ]
      });
      displayResult("\nSMT Token deployed at", smtContract);

      let tx = await smtcCompIns.setSMT(smtContract.address);
      await tx.wait();
      console.log("setted SMT token to smart comp: ", tx.hash);

      let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
      let bal = await smtTokenIns.balanceOf(owner.address);
      console.log("owner SMT balance:", ethers.utils.formatEther(bal.toString()));
      bal = await busdContract.balanceOf(owner.address);
      console.log("owner BUSD balance:", ethers.utils.formatEther(bal.toString()));
    });

    it("Token Transfer 00...", async() => {
      let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
      await displayWalletBalances(smtTokenIns, false, false, false, true); 
      await displayWalletBalances(busdContract, false, false, false, true); 
      let tranferTx =  await smtTokenIns.transfer(
        anotherUser.address,
        ethers.utils.parseUnits("30000", 18)
      );
      await tranferTx.wait();
      console.log("SMT: owner -> another user transfer tx:", tranferTx.hash);
      tranferTx =  await smtTokenIns.transfer(
        wallet1.address,
        ethers.utils.parseUnits("30000", 18)
      );
      await tranferTx.wait();
      console.log("SMT: owner -> wallet1 transfer tx:", tranferTx.hash);

      tranferTx =  await busdContract.transfer(
        anotherUser.address,
        ethers.utils.parseUnits("20000", 18)
      );
      await tranferTx.wait();
      console.log("BUSD: owner -> another user transfer tx:", tranferTx.hash);
      tranferTx =  await busdContract.transfer(
        wallet1.address,
        ethers.utils.parseUnits("20000", 18)
      );
      await tranferTx.wait();
      console.log("BUSD: owner -> wallet1 transfer tx:", tranferTx.hash);

      await displayWalletBalances(smtTokenIns, false, false, false, true); 
      await displayWalletBalances(busdContract, false, false, false, true); 
    });

    it("Add liquidity to liquidity pools...", async() => {
      let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);  
      let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
      routerInstance = new ethers.Contract(
        smtcCompIns.getUniswapV2Router(), uniswapRouterABI, owner
      );
      let pairSmtcBnbAddr = await smtTokenIns._uniswapV2ETHPair();
      console.log("SMT-BNB LP token address: ", pairSmtcBnbAddr);
      let pairSmtcBusdAddr = await smtTokenIns._uniswapV2BUSDPair();
      console.log("SMT-BUSD LP token address: ", pairSmtcBusdAddr);
      let pairSmtBnbIns = new ethers.Contract(pairSmtcBnbAddr, bep20ABI, owner);
      let pairSmtBusdIns = new ethers.Contract(pairSmtcBusdAddr, bep20ABI, owner);

      ///////////////////  SMT-BNB Add Liquidity /////////////////////
      let tx = await smtTokenIns.connect(owner).approve(
        routerInstance.address,
        ethers.utils.parseUnits("10000",18)
      );
      await tx.wait();
      tx = await smtTokenIns.connect(anotherUser).approve(
        routerInstance.address,
        ethers.utils.parseUnits("10000",18)
      );
      await tx.wait();
      tx = await smtTokenIns.connect(wallet1).approve(
        routerInstance.address,
        ethers.utils.parseUnits("10000",18)
      );
      await tx.wait();

      tx = await routerInstance.connect(owner).addLiquidityETH(
        smtTokenIns.address,
        ethers.utils.parseUnits("1000", 18),
        0,
        0,
        owner.address,
        "111111111111111111111",
        {value : ethers.utils.parseUnits("10", 18)}
      );
      await tx.wait();
      console.log("Owner SMT-BNB add liquidity tx: ", tx.hash);

      tx = await routerInstance.connect(anotherUser).addLiquidityETH(
        smtTokenIns.address,
        ethers.utils.parseUnits("1000", 18),
        0,
        0,
        anotherUser.address,
        "111111111111111111111",
        {value : ethers.utils.parseUnits("10", 18)}
      );
      await tx.wait();
      console.log("Another User SMT-BNB add liquidity tx: ", tx.hash);
      
      tx = await routerInstance.connect(wallet1).addLiquidityETH(
        smtTokenIns.address,
        ethers.utils.parseUnits("1000", 18),
        0,
        0,
        wallet1.address,
        "111111111111111111111",
        {value : ethers.utils.parseUnits("10", 18)}
      );
      await tx.wait();
      console.log("Wallet1 SMT-BNB add liquidity tx: ", tx.hash);

      let balance = await pairSmtBnbIns.balanceOf(owner.address);
      console.log("SMT-BNB balance of owner: ", ethers.utils.formatEther(balance));

      ///////////////////  SMT-BUSD Add Liquidity /////////////////////

			tx = await busdContract.connect(owner).approve(
				routerInstance.address,
				ethers.utils.parseUnits("10000", 18)
			);
			await tx.wait();

			tx = await busdContract.connect(anotherUser).approve(
				routerInstance.address,
				ethers.utils.parseUnits("10000", 18)
			);
			await tx.wait();

      tx = await busdContract.connect(wallet1).approve(
				routerInstance.address,
				ethers.utils.parseUnits("10000", 18)
			);
			await tx.wait();

      balance = await busdContract.balanceOf(owner.address);
      console.log("BUSD balance of owner:", ethers.utils.formatEther(balance));
      balance = await ethers.provider.getBalance(owner.address);
      console.log("BNB token balance of owner: ", ethers.utils.formatEther(balance));

      tx = await routerInstance.connect(owner).addLiquidity(
				smtTokenIns.address,
				busdContract.address,
				ethers.utils.parseUnits("1000", 18),
				ethers.utils.parseUnits("1000", 18),
				0,
				0,
				owner.address,
				"111111111111111111111"
			);
			await tx.wait();
      console.log("Owner SMT-BUSD add liquidity tx: ", tx.hash);

			tx = await routerInstance.connect(anotherUser).addLiquidity(
				smtTokenIns.address,
				busdContract.address,
				ethers.utils.parseUnits("1000", 18),
				ethers.utils.parseUnits("1000", 18),
				0,
				0,
				anotherUser.address,
				"111111111111111111111"
			);
			await tx.wait();
      console.log("AnotherUser SMT-BUSD add liquidity tx: ", tx.hash);

			tx = await routerInstance.connect(wallet1).addLiquidity(
				smtTokenIns.address,
				busdContract.address,
				ethers.utils.parseUnits("1000", 18),
				ethers.utils.parseUnits("1000", 18),
				0,
				0,
				wallet1.address,
				"111111111111111111111"
			);
			await tx.wait();
      console.log("Wallet1 SMT-BUSD add liquidity tx: ", tx.hash);

      balance = await pairSmtBusdIns.balanceOf(owner.address);
      console.log("SMT-BUSD balance of owner: ", ethers.utils.formatEther(balance));

    });

    // it("Swap Exchange...", async() => {
    //   let smtcCompIns = await ethers.getContractAt("SmartComp", smartCompContract.address);  
    //   let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
    //   routerInstance = new ethers.Contract(
    //     smtcCompIns.getUniswapV2Router(), uniswapRouterABI, owner
    //   );

    //   let balance = await smtTokenIns.balanceOf(owner.address);
    //   console.log("SMT token balance: ", ethers.utils.formatEther(balance));    
    //   balance = await ethers.provider.getBalance(owner.address);
    //   console.log("BNB token balance: ", ethers.utils.formatEther(balance));

    //   let tx = await smtTokenIns.approve(
    //       routerInstance.address,
    //       ethers.utils.parseUnits("1000", 18)
    //   );
    //   await tx.wait();
    //   let swapAmount = ethers.utils.parseUnits("500", 18);
    //   let amountsOut = await routerInstance.getAmountsOut(
    //     swapAmount,
    //     [
    //       await smtcCompIns.getSMT(), 
    //       await routerInstance.WETH()
    //     ]
    //   );
    //   console.log("excepted swap balance: ", ethers.utils.formatEther(amountsOut[1]));

    //   tx = await routerInstance.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     swapAmount, 0,
    //     [
    //       await smtcCompIns.getSMT(), 
    //       await routerInstance.WETH()
    //     ],
    //     owner.address,
    //     "99000000000000000"
    //   );
    //   await tx.wait();
    //   console.log("swapped tx: ", tx.hash);
    //   balance = await smtTokenIns.balanceOf(owner.address);
    //   console.log("SMT token balance: ", ethers.utils.formatEther(balance));    
    //   balance = await ethers.provider.getBalance(owner.address);
    //   console.log("BNB token balance: ", ethers.utils.formatEther(balance));
    //   cyan("\n==============================================\n");
    //   /////////////////////////////  SMT --> BUSD Swapping ////////////////////////////////
    //   balance = await smtTokenIns.balanceOf(owner.address);
    //   console.log("SMT token balance: ", ethers.utils.formatEther(balance));    
    //   balance = await busdContract.balanceOf(owner.address);
    //   console.log("BUSD token balance: ", ethers.utils.formatEther(balance));

    //   tx = await smtTokenIns.approve(
    //       routerInstance.address,
    //       ethers.utils.parseUnits("1000", 18)
    //   );
    //   await tx.wait();
    //   swapAmount = ethers.utils.parseUnits("200", 18);
    //   amountsOut = await routerInstance.getAmountsOut(
    //     swapAmount,
    //     [
    //       await smtcCompIns.getSMT(), 
    //       await smtcCompIns.getBUSD()
    //     ]
    //   );
    //   console.log("excepted swap balance: ", ethers.utils.formatEther(amountsOut[1]));
    //   tx = await routerInstance.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     swapAmount,
    //     0,
    //     [
    //       await smtcCompIns.getSMT(),
    //       await smtcCompIns.getBUSD()
    //     ],
    //     owner.address,
    //     "99000000000000000"
    //   );
    //   await tx.wait();
    //   console.log("swapped tx: ", tx.hash);
    //   balance = await smtTokenIns.balanceOf(owner.address);
    //   console.log("SMT token balance: ", ethers.utils.formatEther(balance));    
    //   balance = await busdContract.balanceOf(owner.address);
    //   console.log("BUSD token balance: ", ethers.utils.formatEther(balance));
    //   console.log("\n");
    // });

    // it("Token Transfer 11...", async() => {
    //   let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
    //   let tranferTx = await smtTokenIns.connect(anotherUser).transfer(
    //     wallet1.address, 
    //     ethers.utils.parseUnits("1000", 18)
    //   );
    //   await tranferTx.wait();
    //   console.log("another user -> wallet1 transfer tx:", tranferTx.hash);
    //   await displayWalletBalances(smtTokenIns, false, true, false, true);

    //   tranferTx = await smtTokenIns.transfer(
    //     user.address,
    //     ethers.utils.parseUnits("3000", 18)
    //   );
    //   console.log("owner -> user: ", tranferTx.hash);
    // });

    // it("SmartArmy ###  fetch all licenses", async() => {
    //   cyan("============= Created Licenses =============");
    //   let count = await smartArmyContract.countOfLicenses();
    //   cyan(`total license count: ${count}`);
    //   let defaultLics = await smartArmyContract.fetchAllLicenses();
    //   for(let i=0; i<defaultLics.length; i++) {
    //     console.log("************ index",i, " **************");
    //     console.log("level:", defaultLics[i].level.toString());
    //     console.log("name:", defaultLics[i].name.toString());
    //     console.log("price:", ethers.utils.formatEther(defaultLics[i].price.toString()));
    //     console.log("ladderLevel:", defaultLics[i].ladderLevel.toString());
    //     console.log("duration:", defaultLics[i].duration.toString());
    //   }
    // });

    // it("SmartArmy ### register and active license", async() => {
    //   cyan("============= Register Licenses =============");
    //   let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
    //   let userBalance = await smtTokenIns.balanceOf(user.address);
    //   userBalance = ethers.utils.formatEther(userBalance);
    //   const license = await smartArmyContract.licenseTypeOf(1);
    //   let price = ethers.utils.formatEther(license.price);
    //   if(userBalance < price) {
    //     console.log("charge SMT token to your wallet!!!!");
    //     return;
    //   }
    //   let tx = await smartArmyContract.connect(user).registerLicense(
    //     1, anotherUser.address, "Arsenii", "https://t.me.Ivan"
    //   );
    //   await tx.wait();
    //   console.log("register transaction:", tx.hash);
      
    //   tx = await smartArmyContract.connect(user).activateLicense();
    //   console.log("transaction: ", tx.hash);
      
    //   await displayWalletBalances(smtTokenIns, false, false, true, false);
    //   let userLic = await smartArmyContract.licenseOf(user.address);
    //   console.log("----------- user license ---------------");
    //   console.log("owner: ", userLic.owner);
    //   console.log("level: ", userLic.level.toString());
    //   console.log("start at: ", userLic.startAt.toString());
    //   console.log("active at: ", userLic.activeAt.toString());
    //   console.log("expire at: ", userLic.expireAt.toString());
    //   console.log("lp locked: ", ethers.utils.formatEther(userLic.lpLocked.toString()));
    // });

    // it("SmartArmy ### liquidate license", async() => {
    //   let userLic = await smartArmyContract.licenseOf(user.address);
    //   let curBlockNumber = await ethers.provider.getBlockNumber();
    //   const timestamp = (await ethers.provider.getBlock(curBlockNumber)).timestamp;
      
    //   if(userLic.expireAt > timestamp) {
    //     console.log("Current License still active!!!");
    //     return;
    //   }

    //   let smtTokenIns = await ethers.getContractAt("SmartToken", smtContract.address);
    //   displayWalletBalances(smtTokenIns,false,false,true,false);

    //   let tx = await smartArmyContract.connect(user).liquidateLicense();
    //   await tx.wait();

    //   displayWalletBalances(smtTokenIns,false,false,true,false);
    // });

    // it("SmartArmy ### extend license", async() => {

    //   let userLic = await smartArmyContract.licenseOf(user.address);
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

    // it("SmartFarming ### ", async() => {
      
    // });
  });
});