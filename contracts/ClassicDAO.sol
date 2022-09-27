// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
/**
 *   These are some useful tools for ease of use
**/

import "./libraries.sol";

/** 
 * @title DSocDAO Simple Voting Ballot
 * @dev Implements a simple voting process along with vote delegation
 */
contract Ballot {
    // Useful goodies
    using Arrays for uint256[];

    // A proposal is composed of 
    // a time to begin
    // a time to end
    // if it has been executed or not
    struct ProposalCore {
        string proposalName;
        uint voteStart;
        uint voteEnd;
        bool executed;
    }

    // Proposals being tracked here
    ProposalCore[] public proposal;
 
    // Mapping proposal to a number
    // mapping(uint256 => ProposalCore) internal proposalsID;

    function createProposal(string memory name, uint time) external {
        uint beginsNow = block.number;
        uint endsIn = block.number + time;

        string memory proposalName = name;

        proposal.push(
            ProposalCore({
                proposalName: proposalName,
                voteStart: beginsNow,
                voteEnd: endsIn,
                executed: false
            })
        );
    }

    function seeProposalInfo(uint proposalId) public view returns (
        string memory,
        uint,
        uint,
        bool
    ) {
        ProposalCore memory proposal = proposal[proposalId];
           
        return (
            proposal.proposalName,
            proposal.voteStart,
            proposal.voteEnd,
            proposal.executed
        );
    }

}