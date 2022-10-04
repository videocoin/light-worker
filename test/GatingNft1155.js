const { expect } = require("chai");

describe("NFT token gating contract", function () {
  let _name="Test Gating";
  let owner, addr1, addr2, addrs;
  let gatingNft;


  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    
    const GatingNft1155 = await ethers.getContractFactory("GatingNft1155");
    gatingNft = await GatingNft1155.deploy("Test Gating");
  })
  
  describe("Deployment", function () {    
    it("Should has the correct uri", async function () {
      expect(await gatingNft.uri(1)).to.equal(_name);
    });
  })

  describe("Transactions", function () {
    it("Anyone can mint any amount of NFT and become the operator", async function () {
      await gatingNft.connect(addr1).mint(addr1.address, 1, 10, []);
      
      const addr1Balance = await gatingNft.balanceOf(addr1.address, 1);
      const operator = await gatingNft.getTokenOperator(1);
      
      expect(addr1Balance).to.equal(10);
      expect(operator).to.equal(addr1.address);
    });

    it("Light worker dao contract is created when minting new nft", async function () {
      await gatingNft.connect(addr1).mint(addr1.address, 1, 10, []);
      
      const ligthAddr = await gatingNft.getLightWorkerDao(1);
      expect(ligthAddr).to.not.equal(0);
    });

    it("Token id should be added correctly", async function () {
      await gatingNft.connect(addr1).mint(addr1.address, 1, 10, []);
      await gatingNft.connect(addr1).mint(addr1.address, 2, 10, []);

      let ids = await gatingNft.getTokenIDs();
      expect([Number(ids[0]), Number(ids[1])]).to.have.same.members([1, 2]);
    });

    it("Only self minting allowed", async function () {
      await expect(
        gatingNft.connect(addr1).mint(addr2.address, 1, 10, [])
      ).to.be.revertedWith("Only self minting allowed");
    });

    it("Owner can set RewardMgr address", async function () {
      const RewardMgr = await ethers.getContractFactory("RewardMgr");
      const rewardMgr = await RewardMgr.deploy(gatingNft.address);

      await gatingNft.connect(owner).setRewardMgr(rewardMgr.address);
      let rewardMgrAddr = await gatingNft.getRewardMgr()
  
      expect(rewardMgrAddr).to.equal(rewardMgr.address);
    });
  });
})