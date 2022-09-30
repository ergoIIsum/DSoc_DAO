// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

// These are some useful tools for ease of use
import "./libraries.sol";
import "./ClassicDAO.sol";
// TO DO Treasury module
// import "./CLDTreasury.sol";
// TO DO Proposer module
// import "./CLDProposer.sol";

/** 
 * @title ClassicDAO Voting system
 * @dev Implements a simple voting process where 
 * users lock their tokens in order to vote
 * 
 * Incentives are given to winning proposal 
 * voters and deduced from the locked voting power
 */
contract VotingSystem {
    using Arrays for uint256[];
    ClassicDAO internal cld;

    // Hashes for voting options
    bytes32 internal constant approvalHash = keccak256("approve");
    bytes32 internal constant refusalHash = keccak256("refuse");

    // Proposal executioner's bonus, proposal incentive burn percentage 
    uint public execusCut;
    uint public burnCut;
    address public operator;
    uint public memberHolding;

    /* Events
     TO DO:
        TESTING
    */
    event ProposalCreated(address proposer, string proposalName, uint voteStart, uint voteEnd);
    event ProposalExecuted(address executor, uint proposalId, uint amountBurned);
    event CastedVote(uint proposalId, string option, uint votesCasted);
    event ProposalIncentivized(address donator, uint proposalId, uint amountDonated);
    event IncentiveWithdrawed(uint remainingIncentive);

    struct ProposalCore {
        string proposalName;
        uint voteStart;
        uint voteTime;
        uint voteEnd;
        bool executed;
        uint activeVoters;
        uint approvingVotes;
        uint refusingVotes;
        uint incentiveAmount;
        uint incentiveShare;
        uint amountToBurn;
        uint amountToExecutioner;
    }

    struct VoterInfo {
        uint votesLocked;
        // These two below are for debug purposes, TO DO take them out
        uint approvingVotes;
        uint refusingVotes;  
        // These two above are for debug purposes, TO DO take them out
        bool voted;
        bool isExecutioner;
    }

    // Proposals being tracked by id here
    ProposalCore[] internal proposal;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) internal voterInfo;
 
     modifier onlyDAO() {
        _checkIfDAO();
        _;
    }

    modifier onlyHolder() {
        _checkIfHolder();
        _;
    }

    constructor(ClassicDAO cldAddr, address _opAddr, uint _burnCut, uint _execusCut) 
    {
        cld = cldAddr;
        operator = _opAddr;
        burnCut = _burnCut;
        execusCut = _execusCut;
    }

    function createProposal(string memory name, uint time) external onlyHolder {
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
                activeVoters: 0,
                approvingVotes: 0,
                refusingVotes: 0,
                incentiveAmount: 0,
                incentiveShare: 0,
                amountToBurn: 0,
                amountToExecutioner: 0
            })
        );
        emit ProposalCreated(msg.sender, name, beginsNow, endsIn);
    }

    function incentivizeProposal(uint proposalId, uint amount) external {
        require(cld.balanceOf(msg.sender) >= amount, 
        "You do not have enough CLD to stake this amount"
        );
        require(cld.allowance(msg.sender, address(this)) >= amount, 
        "You have not given the staking contract enough allowance"
        );
        require(_doesProposalExists(proposalId), "Proposal doesn't exist!");
        
        ProposalCore storage _proposal = proposal[proposalId];
        require(block.number < _proposal.voteEnd, 
        "The voting period has ended, save for the next proposal!"
        );

        cld.transferFrom(msg.sender, address(this), amount);
        _proposal.incentiveAmount += amount;
        _updateAmountToBurn(proposalId);
        _updateAmountToExecutioner(proposalId);
        _updateIndIncetiveShare(proposalId);

        emit ProposalIncentivized(msg.sender, proposalId, _proposal.incentiveAmount);
    }

    function castVote(
        uint amount,
        uint proposalId, 
        string memory option
        ) 
        external 
    { 
        require(
            cld.balanceOf(msg.sender) >= amount, 
            "You do not have enough CLD to vote this amount"
        );
        require(
            cld.allowance(msg.sender, address(this)) >= amount, 
            "You have not given the voting contract enough allowance"
        );

        bytes32 _optionHash = keccak256(abi.encodePacked(option));
        require(
            _optionHash == approvalHash || _optionHash == refusalHash, 
            "You must either 'approve' or 'refuse'"
        );
        require(_doesProposalExists(proposalId), "Proposal doesn't exist!");

        require(!voterInfo[proposalId][msg.sender].voted, "You already voted in this proposal");
        require(block.number < proposal[proposalId].voteEnd, "The voting period has ended");

        cld.transferFrom(msg.sender, address(this), amount);

        if(_optionHash == approvalHash) {
            proposal[proposalId].approvingVotes += amount;
            voterInfo[proposalId][msg.sender].approvingVotes += amount;
            emit CastedVote(proposalId, "approval", amount);
        } else {
            proposal[proposalId].refusingVotes += amount;
            voterInfo[proposalId][msg.sender].refusingVotes += amount;
            emit CastedVote(proposalId, "refusal", amount);
        }
        voterInfo[proposalId][msg.sender].votesLocked += amount;
        voterInfo[proposalId][msg.sender].voted = true;
        proposal[proposalId].activeVoters += 1;
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
    // Placeholder TO DO

    function executeProposal( uint proposalId) external { 
        voterInfo[proposalId][msg.sender].isExecutioner = true;

        require(_doesProposalExists(proposalId), "Proposal doesn't exist!");
        require(!proposal[proposalId].executed, 'Proposal already executed!');
        require(proposal[proposalId].voteEnd <= block.number, "Voting has not ended");

        proposal[proposalId].executed = true;

        uint burntAmount = _burnIncentiveShare(proposalId);

        emit ProposalExecuted(msg.sender, proposalId, burntAmount);
    }

    function withdrawIncentive(uint proposalId, address voter) external {
        _returnTokens(proposalId, voter, true);
        emit IncentiveWithdrawed(proposal[proposalId].incentiveAmount);
    }

    // TO DO make these three below onlyDAO
    function setBurnAmount(uint amount) external onlyDAO {
        require(msg.sender == operator);
        require(amount < 100);
        burnCut = amount;
    }

    function setExecCut(uint amount) external onlyDAO {
        require(msg.sender == operator);
        require(amount < 100);
        execusCut = amount;
    }

    function setOperator(address newAddr) external onlyDAO {
        require(msg.sender == operator);
        require(operator != newAddr);
        operator = newAddr;
    }

    function updateMemberHolding(uint amount) external onlyDAO {
        memberHolding = amount;
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
    ) 
    {
        ProposalCore memory _proposal = proposal[proposalId];      
        return (
            _proposal.proposalName,
            _proposal.voteStart,
            _proposal.voteTime,
            _proposal.voteEnd,
            _proposal.executed,
            _proposal.activeVoters,
            _proposal.approvingVotes,
            _proposal.refusingVotes,
            _proposal.incentiveAmount
            );
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // WIP [TEST REQUIRED]
    function _returnTokens(
        uint _proposalId,
        address _voterAddr,
        bool _isItForProposals
        )
        internal {
        require(voterInfo[_proposalId][_voterAddr].votesLocked > 0, "You need to lock votes in order to take them out");

        uint _amount = voterInfo[_proposalId][_voterAddr].votesLocked;

        if(_isItForProposals) {
            if(voterInfo[_proposalId][_voterAddr].isExecutioner) {
                uint _specialExecutShare = proposal[_proposalId].incentiveShare + proposal[_proposalId].amountToExecutioner;
                uint _totalAmount = _amount + _specialExecutShare;
                cld.transfer(_voterAddr, _totalAmount);
                proposal[_proposalId].incentiveAmount -= _specialExecutShare;
            } else {
                uint _totalAmount = _amount + proposal[_proposalId].incentiveShare;
                cld.transfer(_voterAddr, _totalAmount);
                proposal[_proposalId].incentiveAmount -= proposal[_proposalId].incentiveShare;  
            }
            voterInfo[_proposalId][_voterAddr].votesLocked -= _amount;
        } else {  // Debug only
            cld.transfer(_voterAddr, _amount);
            voterInfo[_proposalId][_voterAddr].votesLocked -= _amount;
        }
    }

    function _burnIncentiveShare(uint _proposalId) internal returns(uint) {
        uint amount = proposal[_proposalId].amountToBurn;
        cld.Burn(amount);
        proposal[_proposalId].amountToBurn -= amount;

        return(amount);
    }

    function _updateAmountToBurn(uint _proposalId) internal {
        uint baseTokenAmount = proposal[_proposalId].incentiveAmount;
        uint newBurnAmount = baseTokenAmount * burnCut / 100;
        proposal[_proposalId].amountToBurn = newBurnAmount;
    }
    
    function _updateAmountToExecutioner(uint _proposalId) internal {
        uint baseTokenAmount = proposal[_proposalId].incentiveAmount;
        uint newToExecutAmount = baseTokenAmount * execusCut / 100;
        proposal[_proposalId].amountToExecutioner = newToExecutAmount;
    }
        
    function _updateIndIncetiveShare(uint _proposalId) internal {
        uint baseTokenAmount = proposal[_proposalId].incentiveAmount;
        uint totalVoters = proposal[_proposalId].activeVoters;
        uint incentiveTaxes = proposal[_proposalId].amountToBurn + proposal[_proposalId].amountToExecutioner;
        uint newIndividualIncetive = baseTokenAmount - incentiveTaxes / totalVoters;
        proposal[_proposalId].incentiveShare = newIndividualIncetive;
    }   

    function _doesProposalExists(uint _proposalId) internal view returns(bool) {
        // Simple: Does proposal exists (has a name)? Is executed? Is voting ongoing?
        require(keccak256(abi.encodePacked(proposal[_proposalId].proposalName)) != 0);
            return true;
    }

    function _checkIfHolder() internal view {
        address _user = msg.sender;
        uint _userBalance = cld.balanceOf(_user);
        require(_userBalance >= memberHolding, "Sorry, you are not a DAO member"); 
    }

    function _checkIfDAO() internal view {
        address _user = msg.sender;
        require(_user == operator, "This function can only be called by the DAO");
    }

    /////////////////////////////////////////
    /////          Debug Tools          /////
    /////////////////////////////////////////

    function viewVoterInfo(
        address voter, 
        uint proposalId
        ) 
        external view returns (
        uint,
        uint,
        uint,  
        bool 
    ) 
    {
        return (
            voterInfo[proposalId][voter].votesLocked,
            voterInfo[proposalId][voter].approvingVotes,
            voterInfo[proposalId][voter].refusingVotes,
            voterInfo[proposalId][voter].voted
            );
    }

    function takeMyTokensOut(uint proposalId) external {
        _returnTokens(proposalId,msg.sender,false);
    }

    function checkBlock() public view returns (uint){
        return block.number;
    }

}


