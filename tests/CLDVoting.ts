const { assert, expect } = require("chai");
const { BigNumber } = require("ethers");
const { parseEther } = require("ethers/lib/utils");
const { artifacts, contract, hardhat, ethers } = require("hardhat");
const { BN, constants, expectEvent, expectRevert, time } = require("@openzeppelin/test-helpers");

describe("VotingSystem", function () {
    let CLD;
    let Vsystem;

    beforeEach(async () => {
        const [alice] = await ethers.getSigners();

        const cldDeploy = await ethers.getContractFactory('ClassicDAO', alice);
        const CLD = await cldDeploy.deploy(10000000000000, "TestCLD", "TCLD");

        const vSDeploy = await ethers.getContractFactory('VotingSystem');
        const Vsystem = await vSDeploy.deploy(CLD.address);

        return Vsystem;
    });
        it("Testing proposal creation", async function () {

        console.log("Parsing addressess to test 1")

        const votingProposal = await Vsystem.createProposal("Test Proposal 1", 1)

        expectEvent.inTransaction(votingProposal.receipt.transactionHash, Vsystem, "ProposalCreated", {
        to: Vsystem.address,
        value: parseEther("1000000").toString(),
        });
        console.log('Verifying proposal values');

    }); 
        it("Testing vote and incentivize", async function () {
        // Send some CLD to test users, make them approve it to the VotingSystem contract
        const [bob, carol, david, erin] = await ethers.getSigners();

        for (let thisUser of [bob, carol, david, erin]) {
            await CLD.transfer(thisUser.address, 100000)

            await CLD.approve(Vsystem.address, 100000)

        }
        });

});