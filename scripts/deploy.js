const hre = require("hardhat");

const sleep = (milliseconds) => {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
};

const info = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
}

async function main() {

  await info();

  const nftName = "VIVID";

  // We get the contract to deploy
  const GatingNft = await hre.ethers.getContractFactory("GatingNft1155");
  const gatingNft = await GatingNft.deploy(nftName);
  await gatingNft.deployed();
  console.log("GatingNFT deployed to:", gatingNft.address);

  const gateAddress = gatingNft.address;
  await verify(gateAddress, [nftName]);
}

async function verify(contractAddress, arguments){
  await sleep(3* 1000); // await contract is deployed correctly
  try{
        await hre.run("verify:verify", {
          address: contractAddress,
          constructorArguments: arguments
        })
     }
     catch(error) {
        console.error(error);
      };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});