// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "src/FundMe.sol";
import {DeployFundMe} from "script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address alice = makeAddr("alice");
    uint256  constant SEND_VALUE  = 0.1 ether;
    uint256  constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;
    DeployFundMe deployFundMe;

    function setUp() external {
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(alice,STARTING_BALANCE);
    }

    modifier funded() {
        vm.prank(alice);
        fundMe.fund{value:SEND_VALUE}();
        assert(address(this).balance >0);
        _;
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testRvertWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundDataStructure() funded public {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(alice);
        assertEq(amountFunded,SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunder() funded public  {
        address funder = fundMe.getFunders(0);
        assertEq(funder,alice);
    }

    function testOnlyOwnerCanWithdraw() funded public {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() funded public {
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft();

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart-gasEnd)*tx.gasprice;
        console.log("Withdraw consumed: %d gas",gasUsed);

        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;

        assertEq(endingFundMeBalance,0);
        assertEq(startingFundMeBalance+startingOwnerBalance,endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunder() funded public {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex =1;

        for(uint160 i = startingFunderIndex; i< numberOfFunders + startingFunderIndex; i++) {
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value:SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assertEq(address(fundMe).balance,0);
        assertEq(startingFundMeBalance + startingOwnerBalance,fundMe.getOwner().balance);
        assertEq((numberOfFunders + 1) * SEND_VALUE, fundMe.getOwner().balance-startingOwnerBalance);

    }

    function testPrintStorage() view public {
        for(uint256 i = 0; i<3; i++) {
            bytes32 value = vm.load(address(fundMe),bytes32(i));
            console.log("Value at Location",i,":");
            console.logBytes32(value);
        }
        console.log("PriceFeed address:",address(fundMe.getPriceFeed()));
    }

    function testWithdrawFromMultipleFunderCheaper() funded public {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex =1;

        for(uint160 i = startingFunderIndex; i< numberOfFunders + startingFunderIndex; i++) {
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value:SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assertEq(address(fundMe).balance,0);
        assertEq(startingFundMeBalance + startingOwnerBalance,fundMe.getOwner().balance);
        assertEq((numberOfFunders + 1) * SEND_VALUE, fundMe.getOwner().balance-startingOwnerBalance);

    }

}
