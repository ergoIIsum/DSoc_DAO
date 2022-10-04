const { assert, expect } = require("chai");
const { BigNumber } = require("ethers");
const { parseEther } = require("ethers/lib/utils");
const { artifacts, contract, hardhat, ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { BN, constants, expectEvent, expectRevert, time } = require("@openzeppelin/test-helpers");

describe("VotingSystem", function () {

    async function deployContractsFixture() {
        const [alice] = await ethers.getSigners();

        const cldDeploy = await ethers.getContractFactory("ClassicDAO");
        const CLD = await cldDeploy.deploy(10000000000000, "TestCLD", "TCLD");
        await CLD.deployed();
        const aliceBalance = await CLD.balanceOf(alice.address);
        console.log("CLD token deployed at address "+CLD.address);
        console.log(`CLD token owner [alice] has ${aliceBalance} tokens`);

        const vSDeploy = await ethers.getContractFactory("VotingSystem");
        const Vsystem = await vSDeploy.deploy(CLD.address);
        await Vsystem.deployed();

        return { Vsystem, CLD, alice };
    };
        it("Testing proposal creation", async function () {
        const { Vsystem } = await loadFixture(deployContractsFixture);

        //console.log(Vsystem);
        
        expect (await Vsystem.createProposal("Test Proposal 1", 1));

        /*expectEvent.inTransaction(votingProposal.receipt.transactionHash, Vsystem, "ProposalCreated", {
        to: Vsystem.address,
        value: parseEther("1000000").toString(),
        });*/
        console.log('Verifying proposal values');

    }); 
        it("Testing vote and incentivize", async function () {
        /*// Send some CLD to test users, make them approve it to the VotingSystem contract
        const [bob, carol, david, erin] = await ethers.getSigners();

        for (let thisUser of [bob, carol, david, erin]) {
            await CLD.transfer(thisUser.address, 100000)

            await CLD.approve(Vsystem.address, 100000)

        }*/
        });

});