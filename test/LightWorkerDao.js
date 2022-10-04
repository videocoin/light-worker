const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Light Worker Dao contract", function () {
  let owner, addr1, addr2, addrs;
  let gatingNft;
  let lightWorkerDao;

  beforeEach(async function () {
    provider = ethers.getDefaultProvider();
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    
    const GatingNft1155 = await ethers.getContractFactory("GatingNft1155");
    gatingNft = await GatingNft1155.deploy("Test Gating");
    await gatingNft.deployed();
    
    await gatingNft.connect(addr1).mint(addr1.address, 1, 10, []);  // address, tokenId, amount, data
    
    const lightAddr = await gatingNft.getLightWorkerDao(1);         // token Id same as above token Id
    const LightWorkerDao = await ethers.getContractFactory("LightWorkerDao");
    lightWorkerDao = await LightWorkerDao.attach(lightAddr);
    
    await lightWorkerDao.connect(addr1).addPredictionChallenge(
      2,                                    // required amount of proposals
      ethers.utils.parseEther("1"),         // reward amount
      3,                                    // threshold
      0,                                    // min value
      10000,                                // max value
      1000,                                 // valide window
      [],                                   // data
      {value: ethers.utils.parseEther("1")} // reward amount of ether
    );
  })
  
  describe("Transactions", function () {
    it("Addr1 should be added as worker", async function () {
      const workers = await lightWorkerDao.workers(0);
      expect(workers).to.equal(addr1.address);
    });

    // it("Parent(gating nft) can add and remove the worker", async function () {
    //   await hre.network.provider.request({
    //     method: "hardhat_impersonateAccount",
    //     params: [gatingNft.address],
    //   });
    //   const parent = await ethers.getSigner(gatingNft.address);

    //   let [owner, signer] = await ethers.getSigners();

    //   const params = { to: parent.address, gasLimit: "0x5209", value: ethers.utils.parseEther("0.0").toHexString()};
    //   const txHash = await signer.sendTransaction(params);
    //   balance = await provider.getBalance(parent.address);
    //   console.log(balance.toString());
    // });

    it("someone can't add challenge without sufficent reward amount", async function () {
      await expect(
        lightWorkerDao.connect(addr1).addPredictionChallenge(
          2, ethers.utils.parseEther("1"), 100, 0, 10000, 1000, [], 
          {value: ethers.utils.parseEther("0.56")}
        )
      ).to.be.revertedWith("Worker: Insuffient Reward")
    });

    it("someone can add prediction challenge with sufficient reward amount", async function () {
      await lightWorkerDao.connect(addr1).addPredictionChallenge(
        2, ethers.utils.parseEther("1"), 3, 0, 10000, 1000, [], 
        {value: ethers.utils.parseEther("1")}
      );
      const timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
      let { 
        required, 
        rewardAmount, 
        rewardThreshold, 
        minValue, 
        maxValue, 
        creationTime, 
        validWindow
      } = await lightWorkerDao.getPredictionChallenge(1);
      
      expect(Number(required)).to.equal(2);
      expect(Number(rewardAmount)).to.equal(10**18);
      expect(Number(rewardThreshold)).to.equal(3);
      expect(Number(minValue)).to.equal(0);
      expect(Number(maxValue)).to.equal(10000);
      expect(Number(creationTime)).to.equal(timeStamp);
      expect(Number(validWindow)).to.equal(1000);

      await expect(
        lightWorkerDao.getPredictionChallenge(ethers.BigNumber.from(2))
      ).to.be.revertedWith("Worker: Challenge ID out of range");
    });

    it("Only nft holder can submit response", async function () {
      await expect(
        lightWorkerDao.connect(addr2).submitResponse(0, 10)
      ).to.be.revertedWith("Worker: Non-existing Worker");
    });

    it("Nft holder can't submit response to non-existing challenge", async function () {
      await expect(
        lightWorkerDao.connect(addr1).submitResponse(1, 10)
      ).to.be.revertedWith("Worker: Non-exisiting Tx");
    });

    it("Nft holder can submit response to existing challenge and can't send it again", async function () {
      await lightWorkerDao.connect(addr1).submitResponse(0, 10);
      let responseCount = await lightWorkerDao.getResponseCount(0);
      await expect(responseCount).to.be.equal(1);
      await expect(
        lightWorkerDao.connect(addr1).submitResponse(0, 20)
      ).to.be.revertedWith("Worker: Confirmed");
    });
    
    it("users can acquire token after token price is set by owner", async function () {
      await expect(
        lightWorkerDao.connect(addr1).acquireToken({value: ethers.utils.parseEther("0.1")})
        ).to.be.revertedWith("Token price not set yet");
    });
      
    it("users can buy token after token price set", async function () {
      await lightWorkerDao.connect(addr1).setTokenPrice(ethers.utils.parseEther("0.1"));
      await lightWorkerDao.connect(addr2).acquireToken({value: ethers.utils.parseEther("0.1")});
      let balance = await gatingNft.balanceOf(addr2.address, 1);
      expect(Number(balance)).to.be.equal(1);
    });

    it("Release token", async function () {
      await lightWorkerDao.connect(addr1).setTokenPrice(ethers.utils.parseEther("0.1"));
      await lightWorkerDao.connect(addr2).acquireToken({value: ethers.utils.parseEther("0.1")});
      
      let nftBalanceBefore = await gatingNft.balanceOf(addr2.address, 1);
      let ethBalanceBefore = await ethers.provider.getBalance(addr2.address);
      
      await gatingNft.connect(addr2).setApprovalForAll(lightWorkerDao.address, true);
      await lightWorkerDao.connect(addr2).releaseToken();
      
      let nftBalanceAfter = await gatingNft.balanceOf(addr2.address, 1);
      let ethBalanceAfter = await ethers.provider.getBalance(addr2.address);
      
      expect(Number(nftBalanceBefore)).to.be.equal(1);
      expect(Number(nftBalanceAfter)).to.be.equal(0);
      expect(
        Number(ethBalanceAfter - ethBalanceBefore)
      ).to.be.greaterThan(0.098*10**18);
    });
      
    it("Process predictions after collecting required amount of response", async function () {
      await lightWorkerDao.connect(addr1).setTokenPrice(ethers.utils.parseEther("0.1"));
      await lightWorkerDao.connect(addr2).acquireToken({value: ethers.utils.parseEther("0.1")});
      
      let provider = ethers.provider;
      let addr1BalanceBefore = await provider.getBalance(addr1.address);
      let addr2BalanceBefore = await provider.getBalance(addr2.address);

      await lightWorkerDao.connect(addr1).submitResponse(0, 10);
      await lightWorkerDao.connect(addr2).submitResponse(0, 12);
  
      let addr1BalanceAfter = await provider.getBalance(addr1.address);
      let addr2BalanceAfter = await provider.getBalance(addr2.address);
  
      let currentPrediction = await lightWorkerDao.getPredictionValue();
      let challenge = await lightWorkerDao.challenges(0);
      let executed = challenge.executed;
      let predictedValue = challenge.value;
      let pendingIds = await lightWorkerDao.getChallengeIds(0, 1, true, false);
  
      expect(Number(currentPrediction)).to.be.equal(11);
      expect(executed).to.be.equal(true);
      expect(Number(predictedValue)).to.be.equal(11);
      expect(
        Number(addr1BalanceAfter - addr1BalanceBefore)
      ).to.be.greaterThan(0.85*10**18); // addr1 has 9 shares so reward is 0.9
      expect(
        Number(addr2BalanceAfter - addr2BalanceBefore)
      ).to.be.greaterThan(0.03*10**18); // // addr2 has 1 share so reward is 0.1
      expect(Number(pendingIds[0])).to.be.equal(0);
    });
  });
  
})