import { ethers, fhevm } from "hardhat";
import { expect } from "chai";
import { FhevmType } from "@fhevm/hardhat-plugin";

describe("PrivateNFTMarket", function () {
  let market: any, addr: string;
  let owner: any, alice: any, bob: any;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("PrivateNFTMarket");
    market = await Factory.deploy();
    addr = await market.getAddress();
  });

  it("mint, list, place bid, accept bid", async () => {
    // Alice mint NFT
    await (await market.connect(alice).mint()).wait();

    // Alice list NFT for encrypted price = 100
    const enc100 = await fhevm.createEncryptedInput(addr, alice.address).add64(100).encrypt();
    await (await market.connect(alice).list(1, enc100.handles[0], enc100.inputProof)).wait();

    // Bob places encrypted bid = 120
    const enc120 = await fhevm.createEncryptedInput(addr, bob.address).add64(120).encrypt();
    await (await market.connect(bob).placeBid(1, enc120.handles[0], enc120.inputProof)).wait();

    // Alice accepts Bob's bid
    await (await market.connect(alice).acceptBid(1, 0)).wait();

    // NFT ownership should be Bob now
    const newOwner = await market.ownerOf(1);
    expect(newOwner).to.eq(bob.address);
  });
});
