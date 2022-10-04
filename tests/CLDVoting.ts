const { assert, expect } = require("chai");
const { BigNumber } = require("ethers");
const { artifacts, contract, ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { changeTokenBalances } = require("@nomicfoundation/hardhat-chai-matchers");
const { BN, expectEvent, expectRevert, time } = require("@openzeppelin/test-helpers");

describe("VotingSystem", function () {

    async function deployContractsFixture() {
        const [alice, bob, carol, david, erin] = await ethers.getSigners();

        const cldFactory = await ethers.getContractFactory("ClassicDAO");
        const CLD = await cldFactory.deploy(10000000000000, "TestCLD", "TCLD");
        await CLD.deployed();
        expect(
            await CLD.balanceOf(alice.address)
        ).to.equal(10000000000000);

        const vSFactory = await ethers.getContractFactory("VotingSystem");
        const Vsystem = await vSFactory.deploy(CLD.address);
        await Vsystem.deployed();

        let contractOwner = await Vsystem.operator();
        assert.equal(alice.address, contractOwner, "Alice and the contractOwner are not the same!");
        await expect(
            CLD.connect(alice).approve(Vsystem.address, 100000)
        );

        for (let thisUser of [bob, carol, david, erin]) {
            // Send some CLD to test users, make them approve it to the VotingSystem contract
            await expect(
                CLD.connect(alice).transfer(thisUser.address, 100000)
              ).to.changeTokenBalances(CLD, [alice, thisUser], [-100000, 100000]);
            
            await expect(
                CLD.connect(thisUser).approve(Vsystem.address, 100000)
            );

            // Test everything went fine
            expect(await CLD.connect(thisUser).balanceOf(thisUser.address)).to.equal(100000);
            expect(await CLD.allowance(thisUser.address, Vsystem.address)).to.equal(100000);
        }

        expect(await Vsystem.createProposal("Test Proposal 0", 5)).to.emit(Vsystem, 'ProposalCreated');

        let proposalData = await Vsystem.seeProposalInfo(0);
        expect(proposalData[0]).to.have.string('Test Proposal 0');

        return {Vsystem, alice, bob, carol, david, erin} ;
    };

    it("is initialized correctly, with a test proposal set", function () {
    });
/*

    it("is initialized correctly, given the CLD address", function () {
    });

    it("can create proposals", async function () {
        const Vsystem = await loadFixture(deployContractsFixture);

        expect(await Vsystem.createProposal("Test Proposal 0", 5)).to.emit(Vsystem, 'ProposalCreated');

        let proposalData = await Vsystem.seeProposalInfo(0);
        expect(proposalData[0]).to.have.string('Test Proposal 0');
    });
*/
    it("supports voting and incentivizing", async function () {
        const {Vsystem, alice, bob, carol, david, erin} = await loadFixture(deployContractsFixture);
        const [] = await ethers.getSigners();
        
        for (let thisUser of [alice, bob, carol, david, erin]) {
            // let tx = await Vsystem.connect(thisUser).castVote(100, 0, "approve");
            // let receipt: ContractReceipt = await tx.wait(); 

            await expect(
                Vsystem.connect(thisUser).castVote(100, 0, "approve")
            );

            await expect(
                Vsystem.connect(thisUser).incentivizeProposal(0, 20)
            );
            // console.log(await time.latestBlock())
            // await time.advanceBlock()
            // console.log(await time.latestBlock())
            // console.log(thisUser.address);
            let userVotes = await Vsystem.viewVoterInfo(thisUser.address, 0);
            await expect(userVotes[4]).to.be.true;
        }
    
        //let proposalIncentiveAmount = await Vsystem.seeProposalInfo(0)
        //console.log(proposalIncentiveAmount[9].toNumber())
        //expect().to.equal(100);
    });
});