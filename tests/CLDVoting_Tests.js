// Right click on the script name and hit "Run" to execute

import { BigNumber, ethers } from 'ethers'
const { expect } = require("chai");
const { ethers } = require("hardhat");

async function deployContracts() {
    async function deployCDAO() {
        const ClassicDAO = await ethers.getContractFactory('ClassicDAO');
        const classicdao = await ClassicDAO.deploy(10000000000000000000n, "Test Token", "TSTK");
        await classicdao.deployed();
        console.log(`ClassicDAO Test token deployed! at ${classicdao.address}`);

        return classicdao;
    }

    async function deployVSystem() {
        classicdao = await deployCDAO();
        console.log("Parsing ClassicDAO to VotingSystem")

        const VotingSystem = await ethers.getContractFactory("VotingSystem", classicdao.address);
        const votingSystem = await VotingSystem.deploy(classicdao.address);
        await votingSystem.deployed();
        console.log('VotingSystem deployed at:'+ votingSystem.address);
        return [votingSystem, classicdao];
    }

    return deployVSystem();
}

describe("VotingSystem", function () {
  it("Testing proposal creation", async function () {

    let votingSystem = await deployContracts()[0];
    console.log("Parsing addressess to test 1")

    /*const ClassicDAO = await ethers.getContractFactory('ClassicDAO');
    const classicdao = await ClassicDAO.deploy(10000000000000000000n, "Test Token", "TSTK");
    await classicdao.deployed();
    console.log(`ClassicDAO Test token deployed! at ${classicdao.address}`);


    const VotingSystem = await ethers.getContractFactory("VotingSystem", classicdao.address);
    const votingSystem = await VotingSystem.deploy(classicdao.address);
    await votingSystem.deployed();
    console.log('VotingSystem deployed at:'+ votingSystem.address);*/

    expect((await votingSystem.createProposal("Test Proposal 1", 1)));
    console.log('Verifying proposal values');

    let proposalData = await votingSystem.seeProposalInfo(0);
    let parsedProposalData = [];
    let parseHexInProposalData = proposalData.map(function (element) {
        if (BigNumber.isBigNumber(element) && element.gt(0)) {
            parsedProposalData.push(element.toNumber());
        } else if (typeof element == "string") {
            parsedProposalData.push(element);
        }
    })
    console.log("The proposal's name is " +parsedProposalData[0]);
    console.log(`The proposal's start is in ${parsedProposalData[1]} blocks`);
    console.log(`The proposal's duration is ${parsedProposalData[2]} blocks`);
    console.log(`The proposal's end is ${parsedProposalData[3]} blocks`);;
  }); 
   it("Testing vote and incentivize", async function () {
    expect((await votingSystem.createProposal("Test Proposal 2", 5)));
    expect((await votingSystem.castVote(1000, 0, "approve")));
  });
});