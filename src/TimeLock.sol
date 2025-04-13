// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TimeLock合约
 * @notice 这是一个时间锁合约,继承自OpenZeppelin的TimelockController
 * @dev 用于在执行提案前增加时间延迟,提高安全性
 */
contract TimeLock is TimelockController {
    /**
     * @notice 构造函数
     * @param minDelay 最小延迟时间(单位:秒)
     * @param proposers 可以提出提案的地址数组
     * @param executors 可以执行提案的地址数组
     * @dev msg.sender作为管理员地址传入父合约
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
