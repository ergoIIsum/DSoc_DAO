// Right click on the script name and hit "Run" to execute
import { BigNumber, ethers } from 'ethers'
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingSystem", function () {
  it("Testing proposal creation", async function () {
    const ClassicDAO = await ethers.getContractFactory('ClassicDAO');
    const classicdao = await ClassicDAO.deploy(10000000000000000000n, "Test Token", "TSTK");
    await classicdao.deployed();
    console.log(`ClassicDAO Test token deployed! at ${classicdao.address}`);

    const VotingSystem = await ethers.getContractFactory("VotingSystem", classicdao.address);
    const votingSystem = await VotingSystem.deploy(classicdao.address);
    await votingSystem.deployed();
    console.log('VotingSystem deployed at:'+ votingSystem.address);
    expect((await votingSystem.createProposal("Test Proposal 1", 1)));
    console.log('Verifying proposal values');
    let proposalData = await votingSystem.seeProposalInfo(0);
    let parsedProposalData;
    let parseHexInProposalData = proposalData.map(function (element) {
        if (BigNumber.isBigNumber(element) && element.gt(0)) {
            console.log(element.toNumber());
        }
    });
    // expect((await votingSystem.seeProposalInfo(0)));
  }); /*
   it("test updating and retrieving updated value", async function () {
    const Storage = await ethers.getContractFactory("Storage");
    const storage = await Storage.deploy();
    await storage.deployed();
    const storage2 = await ethers.getContractAt("Storage", storage.address);
    const setValue = await storage2.store(56);
    await setValue.wait();
    expect((await storage2.retrieve()).toNumber()).to.equal(56);
  });*/
});