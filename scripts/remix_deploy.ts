// This script can be used to deploy the ClassicDAO system contract using ethers.js library.
// Please make sure to compile "./contracts/CLDVoting.sol" file before running this script.
// And use Right click -> "Run" from context menu of the file to run the script. Shortcut: Ctrl+Shift+S

import { deploy } from './ethers-lib'

(async () => {
    try {
        const classicDao = await deploy('ClassicDAO', [10000000000000000000n, "Test Token", "TSTK"])
        console.log(`address: ${classicDao.address}`)

        const votingSystem = await deploy('VotingSystem', [classicDao.address])
        console.log(`address: ${votingSystem.address}`)
    } catch (e) {
        console.log(e.message)
    }
  })()