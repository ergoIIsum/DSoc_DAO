// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

// These are some useful tools for ease of use
import "./libraries.sol";
// The CLD token ABI
import "./ClassicDAO.sol";
// [WIP] Treasury module
// import "./CLDTreasury";

/** 
 * @title ClassicDAO Voting system
 * @dev Implements a simple voting process where 
 * users lock their tokens in order to vote
 * 
 * Incentives are given to winning proposal 
 * voters and deduced from the locked voting power
 */
contract VotingSystem {
    // Useful goodies
    using Arrays for uint256[];
    ClassicDAO internal cld;

    // A proposal is composed of 
    // a time to begin
    // a time to end
    // if it has been executed or not
    struct ProposalCore {
        string proposalName;
        uint voteStart;
        uint voteTime;
        uint voteEnd;
        bool executed;
        uint voteCount;
        uint approvingVotes;
        uint refusingVotes;
        uint incentiveAmount;
    }

    struct VoterInfo {
        uint votesLocked;
        uint approvingVotes;
        uint refusingVotes;  
        bool voted;
    }

    // Proposals being tracked by id here
    ProposalCore[] public proposal;

    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) internal voterInfo;
 
    // Mapping proposal to a number [Unused code]
    // mapping(uint256 => ProposalCore) internal proposalsID;

    // Hashes for voting options
    bytes32 internal constant approvalHash = keccak256("approve");
    bytes32 internal constant refusalHash = keccak256("refuse");

    constructor(ClassicDAO cldAddr) {
        cld = cldAddr;
    }

    function createProposal(string memory name, uint time) external {
        // Check the proposal name and end time is not empty
        require(keccak256(abi.encodePacked(name)) != 0, "Proposals need a name");
        require(time != 0, "Proposals need an end time");

        uint beginsNow = block.number;
        uint endsIn = block.number + time;

        string memory proposalName = name;

        proposal.push(
            ProposalCore({
                proposalName: proposalName,
                voteStart: beginsNow,
                voteTime: time,
                voteEnd: endsIn,
                executed: false,
                voteCount: 0,
                approvingVotes: 0,
                refusingVotes: 0,
                incentiveAmount: 0
            })
        );
    }

    function seeProposalInfo(uint proposalId) 
    public 
    view 
    returns (
        string memory,
        uint,
        uint,
        uint,
        bool,
        uint,
        uint,
        uint,
        uint
    ) {
        ProposalCore memory _proposal = proposal[proposalId];
           
        return (
            _proposal.proposalName,
            _proposal.voteStart,
            _proposal.voteTime,
            _proposal.voteEnd,
            _proposal.executed,
            _proposal.voteCount,
            _proposal.approvingVotes,
            _proposal.refusingVotes,
            _proposal.incentiveAmount
            );
    }

    // WIP
    function incentivizeProposal(uint amount) public pure returns(uint) {
        return amount;
    }

    function castVote(
        uint amount,
        uint proposalId, 
        string memory option
        ) external { 
        require(cld.balanceOf(msg.sender) >= amount, "You do not have enough CLD to stake this amount");
        require(cld.allowance(msg.sender, address(this)) >= amount, "You have not given the staking contract enough allowance");

        bytes32 _optionHash = keccak256(abi.encodePacked(option));

        require(_optionHash == approvalHash || _optionHash == refusalHash, "You must either 'approve' or 'refuse'");


        ProposalCore storage _proposal = proposal[proposalId];
        VoterInfo storage _voter = voterInfo[proposalId][msg.sender];

        // Check the proposal exists
        require(_doesProposalExists(proposalId), "Proposal doesn't exist!");
        // Check the msg.sender has not voted in this proposal
        require(!_voter.voted, "You already voted in this proposal");
        // Check the vote period has not ended
        require(block.number < _proposal.voteEnd, "The voting period has ended");

        cld.transferFrom(msg.sender, address(this), amount);

        _proposal.voteCount += amount;
        if(_optionHash == approvalHash) {
            _proposal.approvingVotes += amount;
            _voter.approvingVotes += amount;
        } else {
            _proposal.refusingVotes += amount;
            _voter.refusingVotes += amount;
        }
        _voter.votesLocked += amount;
        _voter.voted = true;
       // _voter.optionVoted = _optionHash;
    }

    /*
    function unCastVote(
        uint amount,
        uint proposalId, 
        string calldata option
        ) external { 
    }
    */

    // Proposal execution code
    // Placeholder

    function executeProposal(
        uint proposalId
        // bytes[] memory calldatas
        ) external { 
            ProposalCore storage _proposal = proposal[proposalId];

            require(_doesProposalExists(proposalId), "Proposal doesn't exist!");
            require(!_proposal.executed, 'Proposal already executed!');
            require(_proposal.voteEnd <= block.number, "Voting has not ended");

            _proposal.executed = true;
    }

    // Internal functions

    function _doesProposalExists(uint _proposalId) internal view returns(bool)
    {
        ProposalCore storage _proposal = proposal[_proposalId];

        // Simple: Does proposal exists (has a name)? Is executed? Is voting ongoing?
        require(keccak256(abi.encodePacked(_proposal.proposalName)) != 0);
            return true;
    }

    function _returnTokens(
        uint _proposalId,
        address _voterAddr,
        bool _hasIncentive
        )
        internal returns(bool) {
        VoterInfo storage _voter = voterInfo[_proposalId][_voterAddr];
        require(_voter.voted, "You need to lock votes in order to take them out");


        if(_hasIncentive) {
            // Check the msg.sender has voted

            uint _amount = _voter.votesLocked;
        
            cld.transfer(msg.sender, _amount);
        
            _voter.votesLocked -= _amount;
        } else {
            //placeholder
            return _hasIncentive;
        }
    }

    // Debug tools

    function viewVoterInfo(address voter, uint proposalId) external view returns(
        uint,
        uint,
        uint,  
        bool 
    ) {
        VoterInfo storage _voter = voterInfo[proposalId][voter];

        return(
            _voter.votesLocked,
            _voter.approvingVotes,
            _voter.refusingVotes,
            _voter.voted
            );
    }

    function takeMyTokensOut(uint proposalId) external {
        _returnTokens(proposalId,msg.sender, false);
    }

    function checkBlock() public view returns (uint){
        return block.number;
    }

}


