// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    GovToken govToken;
    TimeLock timeLock;
    MyGovernor myGovernor;

    Box public box;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] public proposers;
    address[] public executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        vm.prank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        myGovernor = new MyGovernor(govToken, timeLock);
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(myGovernor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.prank(USER);
        vm.expectRevert();
        box.store(1);
    }

    function testGovernance() public {
        uint256 value = 77;
        string memory description = "Store 77 in the Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            value
        );

        targets.push(address(box));
        values.push(0); // 添加值为0，因为我们不发送ETH
        calldatas.push(encodedFunctionCall); // 添加编码后的函数调用数据

        // 1.Propose to the DAO
        uint256 proposalId = myGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // View the state
        console.log(
            "Proposal State: %s",
            uint256(myGovernor.state(proposalId))
        );

        // 需要推进到 voteStart 之后的区块
        vm.roll(7202); // 投票开始区块 + 1
        
        console.log(
            "Proposal State: %s",
            uint256(myGovernor.state(proposalId))
        );

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log(
            "Proposal State: %s",
            uint256(myGovernor.state(proposalId))
        );

        // 2.Vote
        string memory reason = "cuz blue frog is cool";

        uint8 voteWay = 1;
        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3.Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4.Execute the TX
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box number is %s", box.readNumber());
        assertEq(box.readNumber(), value);
    }
}
