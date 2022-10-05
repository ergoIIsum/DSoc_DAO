const { assert, expect } = require("chai");
const { BigNumber } = require("ethers");
const { artifacts, contract, ethers, network } = require("hardhat");
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

        expect(await Vsystem.createProposal("Test Proposal 0", 16)).to.emit(Vsystem, 'ProposalCreated');

        let proposalData = await Vsystem.seeProposalInfo(0);
        expect(proposalData[0]).to.have.string('Test Proposal 0');

        return {Vsystem, alice, bob, carol, david, erin} ;
    };

    it("is initialized correctly, with a test proposal set", function () {
    });

    it("supports voting and incentivizing, reverts duplicated votes", async function () {
        const {Vsystem, alice, bob, carol, david, erin } = await loadFixture(deployContractsFixture);

        for (let thisUser of [alice, bob, carol, david, erin]) {
            expect(
                await Vsystem.connect(thisUser).castVote(100, 0, "approve")
            );
            // We won't see this
            await expect(
                Vsystem.connect(thisUser).castVote(100, 0, "approve"), 
            ).to.be.revertedWith('You already voted in this proposal');

            await expect(
                Vsystem.connect(thisUser).incentivizeProposal(0, 20)
            );

            let userVotes = await Vsystem.viewVoterInfo(thisUser.address, 0);
            expect(userVotes[3]).to.be.true;
            assert.equal(userVotes[0], 100, "This message shall not be seen")
        }
    
        let proposalInfo = await Vsystem.seeProposalInfo(0)
        // Total incentive 
        expect(proposalInfo[8]).to.equal(100);
        // Active voters
        expect(proposalInfo[5]).to.equal(5);
        // The individual share of the incentive is 16 
        // (100 total - 10 to burn - 10 to executer) / 5
        expect(proposalInfo[9]).to.equal(16);
    });

    it("supports rejecting votes and incentives after the voting period ends", async function () {
        const {Vsystem, alice, bob } = await loadFixture(deployContractsFixture);
        // Let's push some blocks there to end the voting period
        await network.provider.send("hardhat_mine", ["0x100"]);

        await expect(
            Vsystem.connect(alice).castVote(100, 0, "approve"), 
        ).to.be.revertedWith('The voting period has ended');
        await expect(
            Vsystem.connect(bob).incentivizeProposal(0, 20), 
        ).to.be.revertedWith('The voting period has ended, save for the next proposal!');
    });

    it("rejects unauthorized transactions and checks the taxes are set correctly", async function () {
        const {Vsystem, alice, bob, carol, david } = await loadFixture(deployContractsFixture);
        
        for (let thisUser of [bob, carol, david]) {
            // These should all fail
            await expect(
                Vsystem.connect(thisUser).setTaxAmount(50, "execusCut"), 
            ).to.be.revertedWith('This function can only be called by the DAO');
        }
        for (let thisWord of ["execusCut", "burnCut", "memberHolding"]) {
            // These should all pass
            expect(
                await Vsystem.connect(alice).setTaxAmount(11, `${thisWord}`), 
            );
        }

        let execusCutAmount = await Vsystem.execusCut();
        assert.equal(execusCutAmount, 11, "This message shall not be seen")
        let burnCutAmount = await Vsystem.burnCut();
        assert.equal(burnCutAmount, 11, "This message shall not be seen")
        let memberHoldingAmount = await Vsystem.memberHolding();
        assert.equal(memberHoldingAmount, 11, "This message shall not be seen")

        await expect(
            Vsystem.connect(alice).setTaxAmount(50, "execuCut"), 
        ).to.be.revertedWith("You didn't choose a valid setting to modify!");

        await expect(
            Vsystem.connect(alice).setTaxAmount(0, "execusCut"), 
        ).to.be.revertedWith("This tax can't be zeroed!");



    });

    // it("executes the proposals correctly, burning and paying the executioner's cut", async function () {
    // });

    // it("rejects duplicate names", async function () {
    // });

    // it("pay each voter the respective amount", async function () {
    // });

    // it("helpful comment, add more tests here", async function () {
    // });

    // console.log(await Vsystem.checkBlock())

});