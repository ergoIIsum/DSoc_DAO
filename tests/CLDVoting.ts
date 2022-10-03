// Right click on the script name and hit "Run" to execute

import { assert, expect } from "chai";
import { BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { artifacts, contract, ethers } from "hardhat";

const VotingSystem = artifacts.require("../contracts/[WIP] CLDVoting.sol");
const ClassicDAO = artifacts.require("../contracts/ClassicDAO.sol");

contract("VotingSystem", ([alice, bob, carol, david, erin]) => {
    let CLD
    let Vsystem

    beforeEach(async () => {
        let cldToken = await ClassicDAO.new(10000000000000, "TestCLD", "TCLD", { from: alice });
        let vSystem = await VotingSystem.new(ClassicDAO.address, { from: alice });

        // Send some CLD to test users, make them approve it to the VotingSystem contract
        for (let thisUser of [bob, carol, david, erin]) {

            await cldToken.transfer(thisUser, 100000, { from: alice } )
            await cldToken.approve(vSystem.address, 100000, {from: thisUser})
        }

    });

    describe("test suite", function () {
        it("Testing proposal creation", async function () {

        console.log("Parsing addressess to test 1")

        let votingProposal = await Vsystem.createProposal("Test Proposal 1", 1)

        expectEvent.inTransaction(votingProposal.receipt.transactionHash, Vsystem, "ProposalCreated", {
        from: alice,
        to: Vsystem.address,
        value: parseEther("1000000").toString(),
        });
        console.log('Verifying proposal values');

    }); 
        it("Testing vote and incentivize", async function () {
        });
    });
});