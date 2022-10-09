// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

// These are some useful tools for ease of use
import "./libraries.sol";
import "./ClassicDAO.sol";
import "hardhat/console.sol";
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

    // Proposal executioner's bonus, proposal incentive burn percentage 
    uint public execusCut;
    uint public burnCut;
    uint public memberHolding;
    address public DAO;

    enum Vote {
        Yes,
        No
    }

    event ProposalCreated(address proposer, string proposalName, uint voteStart, uint voteEnd);
    event ProposalExecuted(address executor, uint proposalId, uint amountBurned, uint executShare, string status);
    event CastedVote(uint proposalId, string option, uint votesCasted);
    event ProposalIncentivized(address donator, uint proposalId, uint amountDonated);
    event IncentiveWithdrawed(uint remainingIncentive);

    struct ProposalCore {
        string name;
        uint voteStart;
        uint voteEnd;
        bool executed;
        uint activeVoters;
        uint approvingVotes;
        uint refusingVotes;
        uint incentiveAmount;
        uint incentiveShare;
        uint amountToBurn;
        uint amountToExecutioner;
        string outcome;
    }

    struct VoterInfo {
        uint votesLocked;
        uint amountDonated;
        // These two below are for debug purposes, TO DO take them out
        uint approvingVotes;
        uint refusingVotes;  
        // These two above are for debug purposes, TO DO take them out
        bool voted;
        bool isExecutioner;
    }

    // TO DO Make these internal [after testing]
    // Proposals being tracked by id here
    ProposalCore[] public proposal;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) public voterInfo;
 
     modifier onlyDAO() {
        _checkIfDAO();
        _;
    }

    modifier onlyHolder() {
        _checkIfHolder();
        _;
    }

    constructor(ClassicDAO cldAddr) 
    {
        cld = cldAddr;
        DAO = msg.sender;
        burnCut = 10;
        execusCut = 10;
    }

    // To do people should lock tokens in order to propose?
    function createProposal(string memory name, uint time) external onlyHolder {
        require(keccak256(abi.encodePacked(name)) != 0, "Proposals need a name");
        require(time != 0, "Proposals need an end time");
        
        bytes32 _proposalName = keccak256(abi.encodePacked(name));
        _checkForDuplicate(_proposalName);

        uint beginsNow = block.number;
        uint endsIn = block.number + time;
        proposal.push(
            ProposalCore({
                name: name,
                voteStart: beginsNow,
                voteEnd: endsIn,
                executed: false,
                activeVoters: 0,
                approvingVotes: 0,
                refusingVotes: 0,
                incentiveAmount: 0,
                incentiveShare: 0,
                amountToBurn: 0,
                amountToExecutioner: 0,
                outcome: "Not voted"
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
        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        
        require(block.number < proposal[proposalId].voteEnd, 
        "The voting period has ended, save for the next proposal!"
        );

        cld.transferFrom(msg.sender, address(this), amount);
        proposal[proposalId].incentiveAmount += amount;
        voterInfo[proposalId][msg.sender].amountDonated += amount;
        _updateTaxesAndIndIncentive(proposalId, true);

        emit ProposalIncentivized(msg.sender, proposalId, proposal[proposalId].incentiveAmount);
    }

    function castVote(
        uint amount,
        uint proposalId, 
        uint8 option
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
        require(
            option == 0 || option == 1, 
            "You must either vote 'Yes' or 'No'"
        );
        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        require(!voterInfo[proposalId][msg.sender].voted, "You already voted in this proposal");
        require(block.number < proposal[proposalId].voteEnd, "The voting period has ended");

        cld.transferFrom(msg.sender, address(this), amount);

        if(option == 0) {
            proposal[proposalId].approvingVotes += amount;
            voterInfo[proposalId][msg.sender].approvingVotes += amount;
            emit CastedVote(proposalId, "Yes", amount);
        } else {
            proposal[proposalId].refusingVotes += amount;
            voterInfo[proposalId][msg.sender].refusingVotes += amount;
            emit CastedVote(proposalId, "No", amount);
        }
        voterInfo[proposalId][msg.sender].votesLocked += amount;
        voterInfo[proposalId][msg.sender].voted = true;
        proposal[proposalId].activeVoters += 1;

        _updateTaxesAndIndIncentive(proposalId, false);
    }

    // Proposal execution code
    // Placeholder TO DO
    function executeProposal(uint proposalId) external { 
        voterInfo[proposalId][msg.sender].isExecutioner = true;

        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        require(proposal[proposalId].voteEnd <= block.number, "Voting has not ended");
        require(!proposal[proposalId].executed, "Proposal already executed!");
        require(proposal[proposalId].activeVoters > 0, "Can't execute proposals without voters!");

        uint burntAmount = _burnIncentiveShare(proposalId);
        uint executShare = proposal[proposalId].amountToExecutioner;
        cld.transfer(msg.sender, executShare);
        proposal[proposalId].incentiveAmount -= proposal[proposalId].amountToExecutioner;

        string memory _result;

        if (proposal[proposalId].approvingVotes > proposal[proposalId].refusingVotes) {
            _result = "approved";
            proposal[proposalId].outcome = "Approved";
            // execute payload
        } else {
            _result = "rejected";
            proposal[proposalId].outcome = "Rejected";
            // 
        }

        proposal[proposalId].executed = true;

        emit ProposalExecuted(msg.sender, proposalId, burntAmount, executShare, _result);
    }

    function withdrawMyTokens(uint proposalId) external {
        if (proposal[proposalId].activeVoters > 0) {
            require(proposal[proposalId].executed, 'Proposal has not been executed!');
            _returnTokens(proposalId, msg.sender, true);
        } else {
            _returnTokens(proposalId, msg.sender, true);
        }

        emit IncentiveWithdrawed(proposal[proposalId].incentiveAmount);
    }

    function setTaxAmount(uint amount, string calldata taxToSet) external onlyDAO {
        require(amount < 100, "Percentages can't be higher than 100");
        require(amount > 0, "This tax can't be zeroed!");
        bytes32 _setHash = keccak256(abi.encodePacked(taxToSet));
        bytes32 _execusCut = keccak256(abi.encodePacked("execusCut"));
        bytes32 _burnCut = keccak256(abi.encodePacked("burnCut"));
        bytes32 _memberHolding = keccak256(abi.encodePacked("memberHolding"));

        if (_setHash == _execusCut) {
            execusCut = amount;
        } else if (_setHash == _burnCut) {
            burnCut = amount;
        } else if (_setHash == _memberHolding) {
            memberHolding = amount;
        } else {
            revert("You didn't choose a valid setting to modify!");
        }
    }

    function setDAOAddress(address newAddr) external onlyDAO {
        require(DAO != newAddr, "New DAO address can't be the same as the old one");
        require(DAO != address(0), "New DAO can't be the zero address");
        DAO = newAddr;
    }

    function seeProposalInfo(uint proposalId) 
    public 
    view 
    returns (
        string memory,
        uint,
        uint,
        bool,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        string memory
    ) 
    {
        ProposalCore memory _proposal = proposal[proposalId];      
        return (
            _proposal.name,
            _proposal.voteStart,
            _proposal.voteEnd,
            _proposal.executed,
            _proposal.activeVoters,
            _proposal.approvingVotes,
            _proposal.refusingVotes,
            _proposal.incentiveAmount,
            _proposal.incentiveShare,
            _proposal.amountToBurn,
            _proposal.amountToExecutioner,
            _proposal.outcome
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
        require(block.number > proposal[_proposalId].voteEnd, "The voting period hasn't ended");

        uint _amount = voterInfo[_proposalId][_voterAddr].votesLocked;

        if(_isItForProposals) { // Debug only
            if (proposal[_proposalId].activeVoters > 0) {
                require(
                    voterInfo[_proposalId][_voterAddr].votesLocked > 0, 
                    "You need to lock votes in order to take them out"
                );
                uint _totalAmount = _amount + proposal[_proposalId].incentiveShare;
                cld.transfer(_voterAddr, _totalAmount);
                proposal[_proposalId].incentiveAmount -= proposal[_proposalId].incentiveShare; 
            } else {
                require(
                    voterInfo[_proposalId][_voterAddr].amountDonated > 0, 
                    "You have not incentivized this proposal"
                );
                uint incentiveToReturn = voterInfo[_proposalId][_voterAddr].amountDonated;
                cld.transfer(_voterAddr, incentiveToReturn);
                voterInfo[_proposalId][_voterAddr].amountDonated -= incentiveToReturn;
                proposal[_proposalId].incentiveAmount -= incentiveToReturn;
            }
        } else {  // Debug only
            cld.transfer(_voterAddr, _amount);
        }
        voterInfo[_proposalId][_voterAddr].votesLocked -= _amount;
    }

    function _burnIncentiveShare(uint _proposalId) internal returns(uint) {
        uint amount = proposal[_proposalId].amountToBurn;
        cld.Burn(amount);
        proposal[_proposalId].incentiveAmount -= amount;

        return(amount);
    }

    function _updateTaxesAndIndIncentive(uint _proposalId, bool allOfThem) internal {
        uint baseTokenAmount = proposal[_proposalId].incentiveAmount;

        if (allOfThem) {            
            uint newBurnAmount = baseTokenAmount * burnCut / 100;
            proposal[_proposalId].amountToBurn = newBurnAmount;

            uint newToExecutAmount = baseTokenAmount * execusCut / 100;
            proposal[_proposalId].amountToExecutioner = newToExecutAmount;

            _updateIncentiveShare(_proposalId, baseTokenAmount);
        } else {
            _updateIncentiveShare(_proposalId, baseTokenAmount);
        }

    }

    function _updateIncentiveShare(uint _proposalId, uint _baseTokenAmount) internal {
        uint incentiveTaxes = proposal[_proposalId].amountToBurn + proposal[_proposalId].amountToExecutioner;
        uint totalTokenAmount = _baseTokenAmount - incentiveTaxes;
        if (proposal[_proposalId].activeVoters > 0) {
             uint newIndividualIncetive = totalTokenAmount / proposal[_proposalId].activeVoters;
            proposal[_proposalId].incentiveShare = newIndividualIncetive;
        } else {
            proposal[_proposalId].incentiveShare = totalTokenAmount;
        }
    }

    function _checkIfHolder() internal view {
        if (memberHolding > 0) {
            address _user = msg.sender;
            uint _userBalance = cld.balanceOf(_user);
            require(_userBalance >= memberHolding, "Sorry, you are not a DAO member");
        } 
    }

    function _checkIfDAO() internal view {
        address _user = msg.sender;
        require(_user == DAO, "This function can only be called by the DAO");
    }

    function _checkForDuplicate(bytes32 _proposalName) internal view {
        uint256 length = proposal.length;
        for (uint256 _proposalId = 0; _proposalId < length; _proposalId++) {
            bytes32 _nameHash = keccak256(abi.encodePacked(proposal[_proposalId].name));
            require(_nameHash != _proposalName, "This proposal already exists!");
        }
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
        uint,  
        bool 
    ) 
    {
        return (
            voterInfo[proposalId][voter].votesLocked,
            voterInfo[proposalId][voter].approvingVotes,
            voterInfo[proposalId][voter].refusingVotes,
            voterInfo[proposalId][voter].amountDonated,
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

/** 
 * @title ClassicDAO Execution system
 * @dev Implements a execution layer for 
 * ClassicDAO 
 * 
 * As such, this should be the actual DAO for the whole
 * ClassicDAO system
 */

 // contract Executioner { }
