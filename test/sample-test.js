const { expect } = require("chai");
const { ethers, getNamedAccounts } = require("hardhat");
const chalk = require('chalk');

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

describe("Smtc Ecosystem Contracts Audit", () => {
  const { getContractFactory, getSigners } = ethers;
  // const factors = {
  //   busd: '0xfA249599b353d964768817A75CB4E59d97758B9D',
  //   referral: '0xfA249599b353d964768817A75CB4E59d97758B9D',
  //   goldenTree: '0xDAC575ddcdD2Ff269EE5C30420C96028Ba7cB304',
  //   dev: '0x9D3f7f55DBEb35E734e7405E8CECaDDB8D7e10b0',
  //   achievement: '0x828987A77f7145494bD86780349B204F32DB494A',
  //   farming: '0xb654476d77d59259fF1e7fF38B8c4d408639b844',
  //   intermediary: '0xB5D0D6855EE08eb07eC4Ca51061c93D644367a1e',
  //   smartArmy: '0x86E07ab6b97ADcd7897D960B0c61DFE5CEaD2E76'
  // }
  // const testComp = '0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec';
  const testAdmin = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

  before(async () => {
  });

  it("SMTC Token Testing...", async function () {
    let [owner, user, anotherUser] = await getSigners();
    console.log("owner:", owner.address);
    console.log("user:", user.address);
    console.log("another user:", anotherUser.address);

//////////////////////////////////SmartTokenCash//////////////////////////////////////

    const SmartTokenCash = await ethers.getContractFactory("SmartTokenCash");
    const SmartTokenCashContract = await SmartTokenCash.deploy();
    cyan(`\nDeploying SmartTokenCash Contract...`);
    await SmartTokenCashContract.deployed();
    console.log("smart token cash deployed address:", SmartTokenCashContract.address);
    let SmartTokenCashContractAddress = SmartTokenCashContract.address;

/////////////////////////////////SmartComp////////////////////////////////////////////
    
    const SmartComp = await ethers.getContractFactory("SmartComp");
    const SmartCompContract = await SmartComp.deploy();
    cyan(`\nDeploying SmartComp Contract...`);
    await SmartCompContract.deployed();
    SmartCompContract.initialize();
    console.log("smartComp deployed address:", SmartCompContract.address);
    let SmartCompContractAddress = SmartCompContract.address;

/////////////////////////////////SMTBridge/////////////////////////////////////////////

    let smartCompInstance = await ethers.getContractAt("SmartComp", SmartCompContractAddress);
    // let wbnb = await smartCompInstance.getWBNB();
    let wbnb = '0xfA249599b353d964768817A75CB4E59d97758B9D';
    // let busd = await smartCompInstance.getBUSD();
    let busd = '0x9D3f7f55DBEb35E734e7405E8CECaDDB8D7e10b0';
    // let uniswapV2Factory = await smartCompInstance.getUniswapV2Factory();
    let uniswapV2Factory = '0x86E07ab6b97ADcd7897D960B0c61DFE5CEaD2E76';
    console.log("wbnb:", wbnb);
    console.log("busd:", busd);
    console.log("uniswapV2Factory:", uniswapV2Factory);
    const SMTBridge = await ethers.getContractFactory("SMTBridge");
    const SMTBridgeContract = await SMTBridge.deploy(wbnb, uniswapV2Factory);
    cyan(`\nDeploying SMTBridge Contract...`);
    await SMTBridgeContract.deployed();
    console.log("SMTBridge deployed address:", SMTBridgeContract.address);
    let SMTBridgeContractAddress = SMTBridgeContract.address;

/////////////////////////////////GoldenTreePool////////////////////////////////////////

    const GoldenTreePool = await ethers.getContractFactory("GoldenTreePool");
    const GoldenTreePoolContract = await GoldenTreePool.deploy();
    cyan(`\nDeploying GoldenTreePool Contract...`);
    await GoldenTreePoolContract.deployed();
    GoldenTreePoolContract.initialize(SmartCompContractAddress, SmartTokenCashContractAddress);
    console.log("GoldenTreePool deployed address:", GoldenTreePoolContract.address);
    let GoldenTreePoolContractAddress = GoldenTreePoolContract.address;

/////////////////////////////////SmartAchievement//////////////////////////////////////

    const SmartAchievement = await ethers.getContractFactory("SmartAchievement");
    const SmartAchievementContract = await SmartAchievement.deploy();
    cyan(`\nDeploying SmartAchievement Contract...`);
    await SmartAchievementContract.deployed();
    // SmartAchievementContract.initialize(SmartCompContractAddress, SmartTokenCashContractAddress);
    console.log("SmartAchievement deployed address:", SmartAchievementContract.address);
    let SmartAchievementContractAddress = SmartAchievementContract.address;

/////////////////////////////////SmartArmy/////////////////////////////////////////////

    const SmartArmy = await ethers.getContractFactory("SmartArmy");
    const SmartArmyContract = await SmartArmy.deploy();
    cyan(`\nDeploying SmartArmy Contract...`);
    await SmartArmyContract.deployed();
    // SmartArmyContract.initialize(SmartCompContractAddress);
    console.log("SmartArmy deployed address:", SmartArmyContract.address);
    let SmartArmyContractAddress = SmartArmyContract.address;

////////////////////////////////SmartFarm//////////////////////////////////////////////

    const SmartFarm = await ethers.getContractFactory("SmartFarm");
    const SmartFarmContract = await SmartFarm.deploy();
    const RewardWalletAddress = '0x828987A77f7145494bD86780349B204F32DB494A';
    cyan(`\nDeploying SmartFarm Contract...`);
    await SmartFarmContract.deployed();
    // SmartFarmContract.initialize(SmartCompContractAddress, RewardWalletAddress);
    console.log("SmartFarm deployed address:", SmartFarmContract.address);
    let SmartFarmContractAddress = SmartFarmContract.address;

////////////////////////////////SmartLadder///////////////////////////////////////////

    const SmartLadder = await ethers.getContractFactory("SmartLadder");
    const SmartLadderContract = await SmartLadder.deploy();
    cyan(`\nDeploying SmartLadder Contract...`);
    await SmartLadderContract.deployed();
    SmartLadderContract.initialize(SmartCompContractAddress, testAdmin);
    console.log("SmartLadder deployed address:", SmartLadderContract.address);
    let SmartLadderContractAddress = SmartLadderContract.address;

////////////////////////////// BUSD Token /////////////////////////////////////////
    const BusdContract = await ethers.getContractFactory("FakeUsdt");
    const busdContract = await BusdContract.deploy();
    cyan(`\nDeploying BUSD token...`);
    await busdContract.deployed();
    console.log("BUSD contract address: ", busdContract.address);

///////////////////////////// SMT Token ///////////////////////////////////////

    cyan(`\nDeploying SMT token...`);
    const SmartToken = await ethers.getContractFactory("SmartToken");
    const smtcContract = await SmartToken.deploy(
      busdContract.address,
      SmartLadderContractAddress,
      GoldenTreePoolContractAddress,
      owner.address,
      owner.address,
      SmartFarmContractAddress,
      SMTBridgeContractAddress,
      SmartArmyContractAddress,
      SmartCompContractAddress,
      owner.address
    );
    await smtcContract.deployed();
    console.log("SMT contract address: ", smtcContract.address);

    SmartCompContract.connect(owner).setBUSD(busdContract.address);
    SmartCompContract.connect(owner).setSMT(smtcContract.address);

    cyan("-------------------------------------------------------");
    console.log(">>>>>>>>>>>  Buy SMT Token With BUSD  >>>>>>>>>>>");
    cyan("-------------------------------------------------------");
    let bal = await busdContract.balanceOf(owner.address);
    console.log("owner BUSD balance:", ethers.utils.formatEther(bal.toString()));

    // for testing transfer
    let transferTx =  await busdContract.transfer(anotherUser.address, ethers.utils.parseUnits("100000", 18));
    await transferTx.wait();
    console.log("transfer tx1:", transferTx.hash);

    bal = await busdContract.balanceOf(owner.address);
    console.log("owner BUSD balance: ", ethers.utils.formatEther(bal.toString()));
    bal = await busdContract.balanceOf(anotherUser.address);
    console.log("another user BUSD balance: ", ethers.utils.formatEther(bal.toString()));
    console.log("------------------------------------");
    // console.log("owner 1:", owner.address);
    let tx = await busdContract.connect(anotherUser).approve(smtcContract.address, ethers.utils.parseUnits('10000',18));
    await tx.wait();
    tx = await smtcContract.connect(anotherUser).buyTokenWithBUSD(10000);
    await tx.wait();
    bal = await busdContract.balanceOf(anotherUser.address);
    console.log("another user BUSD balance: ", ethers.utils.formatEther(bal.toString()));
    bal = await smtcContract.balanceOf(anotherUser.address);
    console.log("another user SMT balance: ", ethers.utils.formatEther(bal.toString()));

    cyan("-------------------------------------------------------");
    console.log(">>>>>>>>>>>  Buy SMT Token With BNB  >>>>>>>>>>>");
    cyan("-------------------------------------------------------");

    bal = await ethers.provider.getBalance(anotherUser.address);
    console.log("another user BNB balance: ", ethers.utils.formatEther(bal.toString()));
    console.log("------------------------------------");

    tx = await smtcContract.connect(anotherUser).buyTokenWithBNB({value: ethers.utils.parseUnits("10",18)});
    await tx.wait();

    bal = await ethers.provider.getBalance(anotherUser.address);
    console.log("another user BNB balance: ", ethers.utils.formatEther(bal.toString()));
    bal = await smtcContract.balanceOf(anotherUser.address);
    console.log("another user SMT balance: ", ethers.utils.formatEther(bal.toString()));

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});