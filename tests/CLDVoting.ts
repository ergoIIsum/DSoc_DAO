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
        const CLD = await cldFactory.deploy(20000000000000000000n, "TestCLD", "TCLD");
        await CLD.deployed();
        expect(
            await CLD.balanceOf(alice.address)
        ).to.equal(20000000000000000000n);

        const vSFactory = await ethers.getContractFactory("VotingSystem");
        const Vsystem = await vSFactory.deploy(CLD.address);
        await Vsystem.deployed();

        let contractOwner = await Vsystem.operator();
        assert.equal(alice.address, contractOwner, "Alice and the contractOwner are not the same!");
        await expect(
            CLD.connect(alice).approve(Vsystem.address, 10000000000000000000n)
        );

        for (let thisUser of [bob, carol, david, erin]) {
            // Send some CLD to test users, make them approve it to the VotingSystem contract
            await expect(
                CLD.connect(alice).transfer(thisUser.address, 1000000000000000000n)
              ).to.changeTokenBalances(CLD, [alice, thisUser], [-1000000000000000000n, 1000000000000000000n]);
            
            await expect(
                CLD.connect(thisUser).approve(Vsystem.address, 1000000000000000000n)
            );

            // Test everything went fine
            expect(await CLD.balanceOf(thisUser.address)).to.equal(1000000000000000000n);
            expect(await CLD.allowance(thisUser.address, Vsystem.address)).to.equal(1000000000000000000n);
        }

        expect(await Vsystem.createProposal("Test Proposal 0", 16)).to.emit(Vsystem, 'ProposalCreated');

        let proposalData = await Vsystem.seeProposalInfo(0);
        expect(proposalData[0]).to.have.string('Test Proposal 0');

        return {Vsystem, alice, bob, carol, david, erin, CLD} ;
    };

    it("is initialized correctly, with a test proposal set", function () {
    });

    it("supports voting and incentivizing, reverts duplicated votes", async function () {
        const {Vsystem, alice, bob, carol, david, erin } = await loadFixture(deployContractsFixture);

        for (let thisUser of [alice, bob, carol, david, erin]) {
            expect(
                await Vsystem.connect(thisUser).castVote(100, 0, "approve")
            ).to.emit(Vsystem, "CastedVote");
            // We won't see this
            await expect(
                Vsystem.connect(thisUser).castVote(100, 0, "approve"), 
            ).to.be.revertedWith('You already voted in this proposal');

            await expect(
                Vsystem.connect(thisUser).incentivizeProposal(0, 20)
            ).to.emit(Vsystem, "ProposalIncentivized");

            let userVotes = await Vsystem.viewVoterInfo(thisUser.address, 0);
            expect(userVotes[4]).to.be.true;
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
        await network.provider.send("hardhat_mine", ["0x20"]);

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
            // These should all fail, users are not alice
            await expect(
                Vsystem.connect(thisUser).setTaxAmount(50, "execusCut"), 
            ).to.be.revertedWith('This function can only be called by the DAO');
        }
        for (let thisWord of ["execuCut", "burCut", "membeHolding"]) {
            // These should all fail, the string have typos
            await expect(
                Vsystem.connect(alice).setTaxAmount(11, `${thisWord}`), 
            ).to.be.revertedWith("You didn't choose a valid setting to modify!");
        }
        for (let thisWord of ["execusCut", "burnCut", "memberHolding"]) {
            // These should all pass
            expect(
                await Vsystem.connect(alice).setTaxAmount(11, `${thisWord}`), 
            );
            // These should fail
            await expect(
                Vsystem.connect(alice).setTaxAmount(0, `${thisWord}`), 
            ).to.be.revertedWith("This tax can't be zeroed!");
            await expect(
                Vsystem.connect(alice).setTaxAmount(101, `${thisWord}`), 
            ).to.be.revertedWith("Percentages can't be higher than 100");
        }

        let execusCutAmount = await Vsystem.execusCut();
        assert.equal(execusCutAmount, 11, "This message shall not be seen 1")
        let burnCutAmount = await Vsystem.burnCut();
        assert.equal(burnCutAmount, 11, "This message shall not be seen 2")
        let memberHoldingAmount = await Vsystem.memberHolding();
        assert.equal(memberHoldingAmount, 11, "This message shall not be seen 3")
    });

    it("executes the proposals correctly, burning and paying the executioner's cut", async function () {
        const {Vsystem, alice, bob, carol, david, erin, CLD } = await loadFixture(deployContractsFixture);
        expect(await CLD.balanceOf(erin.address)).to.equal(1000000000000000000n);

        for (let thisUser of [alice, bob, carol, david]) {
            expect(
                await Vsystem.connect(thisUser).castVote(100, 0, "approve")
            );

            await expect(
                Vsystem.connect(thisUser).incentivizeProposal(0, 235720)
            ).to.emit(Vsystem, "ProposalIncentivized");
                
            let proposalData = await Vsystem.seeProposalInfo(0)

            let userData = await Vsystem.viewVoterInfo(thisUser.address, 0);
            expect(userData[4]).to.be.true;
            expect(await CLD.balanceOf(Vsystem.address)).to.equal((userData[0]*proposalData[5])+(userData[3]*proposalData[5]));
            assert.equal(userData[0], 100, "This message shall not be seen");
        }

        let proposalInfBfr = await Vsystem.seeProposalInfo(0);
        let voterDonated = (await Vsystem.viewVoterInfo(alice.address ,0))[3]
        // Total incentive 
        expect(proposalInfBfr[8]).to.equal((await voterDonated.toNumber()*proposalInfBfr[5]));
        // Active voters
        expect(proposalInfBfr[5]).to.equal(4);
        // Burn amount
        let burnAm = proposalInfBfr[10];
        // Execus cut
        let excCut = proposalInfBfr[11];
        // The individual share of the incentives
        expect(proposalInfBfr[9]).to.equal((proposalInfBfr[8]-burnAm.toNumber()-excCut.toNumber())/proposalInfBfr[5]);

        await network.provider.send("hardhat_mine", ["0x17"]);
        await expect(
            Vsystem.connect(erin).executeProposal(0)
        ).to.emit(Vsystem, "ProposalExecuted");

        // Check it's actually executed
        let proposalInfo = await Vsystem.seeProposalInfo(0);
        let execusCut = await Vsystem.execusCut();
        let burnCut = await Vsystem.burnCut();
        let totalTax = ((execusCut.toNumber()+burnCut.toNumber())*100)/100;
        expect(proposalInfo[4]).to.be.true;
        // Check ind share now
        expect(proposalInfo[9]).to.equal((proposalInfBfr[8]-proposalInfBfr[10]-proposalInfBfr[11])/proposalInfBfr[5]);
        // Total incentive now 
        expect(proposalInfo[8]).to.equal(proposalInfBfr[8] - ((proposalInfBfr[8]*totalTax)/100));
        // Active voters
        expect(proposalInfo[5]).to.equal(4);
        // Check erin received the tokens
        expect(await CLD.balanceOf(erin.address)).to.equal(BigInt(excCut) + 1000000000000000000n);
        // The balance on the contract should be:
        //The initial incentive amount (before the execution) minus the taxes plus the amount of votes casted
        expect(await CLD.balanceOf(Vsystem.address)).to.equal(proposalInfBfr[8]-proposalInfBfr[10]-proposalInfBfr[11]+400);
    });

    it("rejects duplicate names", async function () {
        const { Vsystem } = await loadFixture(deployContractsFixture);

        await expect(Vsystem.createProposal("Test Proposal 0", 16)).to.be.revertedWith('This proposal already exists!');
    });

    // it("pay each voter the respective amount", async function () {
    // });

    // it("helpful comment, add more tests here", async function () {
    // });

    // console.log(await Vsystem.checkBlock())

});