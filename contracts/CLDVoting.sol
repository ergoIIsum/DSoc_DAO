// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

// These are some useful tools for ease of use
import "./libraries.sol";

// The CLD token ABI
import "./ClassicDAO.sol";

/** 
 * @title ClassicDAO Voting system
 * @dev Implements a simple voting process where 
 * users lock their tokens in order to vote
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
    }

    struct VoterInfo {
        uint votesLocked;
        bytes32 optionVoted;
        uint approvingVotes;
        uint refusingVotes;  
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
                refusingVotes: 0
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
            _proposal.refusingVotes
            );
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

        cld.transferFrom(msg.sender, address(this), amount);

        _proposal.voteCount += amount;
        if(_optionHash == approvalHash) {
            _proposal.approvingVotes += amount;
        } else {
            _proposal.refusingVotes += amount;
        }
        _voter.votesLocked += amount;
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
    // Do it in a different contract?

    function executeProposal(
        uint proposalId
        // bytes[] memory calldatas
        ) external { 
            ProposalCore storage _proposal = proposal[proposalId];

            require(!_proposal.executed, 'Proposal already executed!');
            require(block.number > _proposal.voteEnd, "Voting is not over!");

            _proposal.executed = true;
    }

    // Debug tools

    function checkBlock() public view returns (uint){
        return block.number;
    }

    function returnTokens(uint proposalId, string memory option) external {
        ProposalCore storage _proposal = proposal[proposalId];
        VoterInfo storage _voter = voterInfo[proposalId][msg.sender];

        bytes32 _optionHash = keccak256(abi.encodePacked(option));

        require(_optionHash == approvalHash || _optionHash == refusalHash, "You must either 'approve' or 'refuse'");

        uint _amount = _voter.votesLocked;
        
        cld.transferFrom(address(this), msg.sender, _amount);
        if(_optionHash == approvalHash) {
            _proposal.approvingVotes -= _amount;
        } else {
            _proposal.refusingVotes -= _amount;
        }
        _voter.votesLocked = 0;

    }

}