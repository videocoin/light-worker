const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Checking the number of light workers via stress testing", function () {
  let addrs;
  let addr1;
  let gatingNft;
  let lightWorkerDao;
  const maxWinners = 100;

  beforeEach(async function () {
    addrs = await ethers.getSigners();
    addr1 = addrs[0];
    
    const GatingNft1155 = await ethers.getContractFactory("GatingNft1155");
    gatingNft = await GatingNft1155.deploy("Test Gating");
    await gatingNft.deployed();
    
    await gatingNft.connect(addr1).mint(addr1.address, 1, maxWinners + 10, []);  // address, tokenId, amount, data
    
    const lightAddr = await gatingNft.getLightWorkerDao(1);         // token Id same as above token Id
    const LightWorkerDao = await ethers.getContractFactory("LightWorkerDao");
    lightWorkerDao = await LightWorkerDao.attach(lightAddr);
    
    await lightWorkerDao.connect(addr1).addPredictionChallenge(
      maxWinners,                           // required amount of proposals
      ethers.utils.parseEther("1"),         // reward amount
      5000,                                 // threshold
      0,                                    // min value
      10000,                                // max value
      1000,                                 // valid window
      [],                                   // data
      {value: ethers.utils.parseEther("1")} // reward amount of ether
    );
  })
  
  it("Process predictions after collecting required amount of responses", async function () {
    console.log("=====The number of winners is " + maxWinners + ".======");
    await lightWorkerDao.connect(addr1).setTokenPrice(ethers.utils.parseEther("0.1"));
    if (maxWinners > addrs.length) {
      for (let i = addrs.length; i < maxWinners; i++) {
        let wallet = await ethers.Wallet.createRandom();
        wallet = wallet.connect(ethers.provider);
        await addr1.sendTransaction({to: wallet.address, value: ethers.utils.parseEther("1")});
        addrs.push(wallet);
      }
    }

    for (let i = 1; i < Math.min(addrs.length, maxWinners); i++) {
      await lightWorkerDao.connect(addrs[i]).acquireToken({value: ethers.utils.parseEther("0.1")});
    }

    let provider = ethers.provider;
    let addr3BalanceBefore = await provider.getBalance(addrs[3].address);

    let proposals = [];
    for (let addr of addrs.slice(0, maxWinners)) {
      let randNum = Math.floor(Math.random() * 10000);
      proposals.push(randNum);
      await lightWorkerDao.connect(addr).submitResponse(0, randNum);
    }

    let addr3BalanceAfter = await provider.getBalance(addrs[3].address);
    
    let median;
    const mid = Math.floor(proposals.length / 2),
      nums = [...proposals].sort((a, b) => a - b);
    median = proposals.length % 2 !== 0 ? nums[mid] : (nums[mid - 1] + nums[mid]) / 2;
    median = Math.floor(median);

    let challenge = await lightWorkerDao.challenges(0);
    let executed = challenge.executed;
    let predictedValue = challenge.value;

    expect(Number(predictedValue)).to.be.equal(median);
    expect(executed).to.be.equal(true);
    expect(
      Number(addr3BalanceAfter - addr3BalanceBefore)
    ).to.be.greaterThan(0);
  });
});